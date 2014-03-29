//
//  AGSClusterLayer.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterLayer.h"
#import "AGSClusterGrid.h"
#import "AGSCluster.h"
#import "Common.h"
#import <objc/runtime.h>

#pragma mark - Constants and Defines
#define kClusterRenderBlockParameterKey @"clusterBlock"
#define kCoverageRenderBlockParameterKey @"coverageBlock"

#define kLODLevelScale @"scale"
#define kLODLevelResolution @"resolution"
#define kLODLevelZoomLevel @"level"
#define kLODLevelCellSize @"cellSize"
#define kLODLevelGrid @"grid"

#define kDefaultMinClusterCount 2

#define kClusterNotificationUserInfoKey_Duration @"duration"
#define kClusterNotificationUserInfoKey_ClusterCount @"clusterCount"
#define kClusterNotificationUserInfoKey_FeatureCount @"clusterCount"
#define kClusterNotificationUserInfoKey_CellSize @"clusterCount"

NSString * const AGSClusterLayerDidCompleteClusteringNotification = @"AGSClusterLayerClusteringCompleteNotification";
NSString * const AGSClusterLayerDidCompleteClusteringNotificationUserInfo_Duration = kClusterNotificationUserInfoKey_Duration;
NSString * const AGSClusterLayerDidCompleteClusteringNotificationUserInfo_ClusterCount = kClusterNotificationUserInfoKey_ClusterCount;
NSString * const AGSClusterLayerDidCompleteClusteringNotificationUserInfo_FeatureCount = kClusterNotificationUserInfoKey_FeatureCount;
NSString * const AGSClusterLayerDidCompleteClusteringNotificationUserInfo_ClusteringCellsize = kClusterNotificationUserInfoKey_CellSize;

#pragma mark - Internal properties
@interface AGSClusterLayer () <AGSLayerCalloutDelegate>

@property (nonatomic, strong) AGSClusterGrid *grid;
@property (nonatomic, strong) NSMutableDictionary *grids;
@property (nonatomic, strong) NSArray *sortedGridKeys;

@property (nonatomic, strong) NSArray *lodData;

@property (nonatomic, weak) AGSFeatureLayer *featureLayer;
@property (nonatomic, strong) NSMutableDictionary *lazyLoadParameters;
@property (nonatomic, assign, readwrite) BOOL willClusterAtCurrentScale;

@property (nonatomic, assign) BOOL mapViewLoaded;

@property (nonatomic, strong) NSNumber *maxZoomLevel;
@end


#pragma mark - Synthesizers
@implementation AGSClusterLayer
@synthesize willClusterAtCurrentScale = _willClusterAtCurrentScale;

#pragma mark - Convenience Constructors
+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer {
    return [[AGSClusterLayer alloc] initWithFeatureLayer:featureLayer];
}

+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer
                        usingClusterSymbolBlock:(AGSClusterSymbolGeneratorBlock)clusterBlock
                            coverageSymbolBlock:(AGSClusterSymbolGeneratorBlock)coverageBlock {
    AGSClusterLayer *newLayer = [AGSClusterLayer clusterLayerForFeatureLayer:featureLayer];
    if (clusterBlock) [newLayer.lazyLoadParameters setObject:clusterBlock forKey:kClusterRenderBlockParameterKey];
    if (coverageBlock) [newLayer.lazyLoadParameters setObject:coverageBlock forKey:kCoverageRenderBlockParameterKey];
    return newLayer;
}

#pragma mark - Initializers
-(id)init {
    self = [super init];
    if (self) {
        self.mapViewLoaded = NO;
        self.showClusterCoverages = NO;
        self.calloutDelegate = self;
        self.minClusterCount = kDefaultMinClusterCount;
        self.lazyLoadParameters = [NSMutableDictionary dictionary];
        self.minScaleForClustering  = 0;
        self.grids = [NSMutableDictionary dictionary];
        self.lodData = [self defaultLodData];
        [self parseLodData];
    }
    return self;
}

-(void)setMapView:(AGSMapView *)mapView {
    self.mapViewLoaded = self.mapView.loaded;
    [super setMapView:mapView];
}

-(void)setMapViewLoaded:(BOOL)mapViewLoaded {
    _mapViewLoaded = mapViewLoaded;
    if (_mapViewLoaded) {
        [self.mapView removeObserver:self forKeyPath:@"loaded"];
    } else {
        [self.mapView addObserver:self forKeyPath:@"loaded" options:NSKeyValueObservingOptionNew context:nil];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.mapView && [keyPath isEqualToString:@"loaded"]) {
        self.mapViewLoaded = self.mapView.loaded;
    }
}

-(void)parseLodData {
    for (NSDictionary *lodInfo in self.lodData) {
        [self.grids setObject:[NSMutableDictionary dictionaryWithDictionary:lodInfo]
                       forKey:lodInfo[kLODLevelZoomLevel]];
    }
    self.sortedGridKeys = [self.grids.allKeys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [((NSNumber *)obj1) compare:obj2];
    }];
}

-(id)initWithFeatureLayer:(AGSFeatureLayer *)featureLayer {
    self = [self init];
    if (self) {
        self.featureLayer = featureLayer;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(featureLayerLoaded:)
                                                     name:AGSLayerDidLoadNotification
                                                   object:self.featureLayer];
    }
    return self;
}

#pragma mark - Asynchronous Setup
-(void)featureLayerLoaded:(NSNotification *)notification {
    NSLog(@"Stealing renderer...");
    AGSClusterSymbolGeneratorBlock clusterGenBlock = self.lazyLoadParameters[kClusterRenderBlockParameterKey];
    AGSClusterSymbolGeneratorBlock coverageGenBlock = self.lazyLoadParameters[kCoverageRenderBlockParameterKey];
    self.lazyLoadParameters = nil;
    
    self.renderer = [[AGSClusterLayerRenderer alloc] initAsSurrogateFor:self.featureLayer.renderer
                                                     clusterSymbolBlock:clusterGenBlock
                                                    coverageSymbolBlock:coverageGenBlock];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(featuresLoaded:)
                                                 name:AGSFeatureLayerDidLoadFeaturesNotification
                                               object:self.featureLayer];
    self.featureLayer.opacity = 0;
    
    [self calculateLods];
}

-(void)calculateLods {
    CGFloat cellSizeInInches = 0.25;
    AGSUnits mapUnits = self.mapViewLoaded?AGSUnitsFromSpatialReference(self.mapView.spatialReference):AGSUnitsMeters;
    AGSUnits screenUnits = AGSUnitsInches;
    double cellSizeInMapUnits = AGSUnitsToUnits(cellSizeInInches, screenUnits, mapUnits);

    for (NSNumber *zoomLevel in self.sortedGridKeys) {
        NSMutableDictionary *d = self.grids[zoomLevel];
        double scale = [d[kLODLevelScale] doubleValue];
        double resolution = [d[kLODLevelResolution] doubleValue];
        NSUInteger cellSize = floor(cellSizeInMapUnits * scale);
        d[kLODLevelCellSize] = @(cellSize);
        d[kLODLevelGrid] = [[AGSClusterGrid alloc] initWithCellSize:cellSize];
        NSLog(@"Zoom Level %2d has cell size %7d [%.4f, %.4f]", [zoomLevel unsignedIntegerValue], cellSize, scale, resolution);
        self.maxZoomLevel = zoomLevel;
    }
    NSLog(@"Max Zoom Level %@", self.maxZoomLevel);
}

-(NSUInteger)getZoomForScale:(double)scale {
    NSNumber *lastZoomLevel = nil;
    for (NSNumber *zoomLevel in [self.sortedGridKeys reverseObjectEnumerator]) {
        NSDictionary *d = self.grids[zoomLevel];
        double scaleForZoom = [d[kLODLevelScale] doubleValue];
        NSLog(@"Finding Zoom Level for scale %.4f: %@ [%4f]", scale, zoomLevel, scaleForZoom);
        if (scale <= scaleForZoom) {
            // This is our ZoomLevel
            NSLog(@"ZOOM LEVEL %@", zoomLevel);
            return [zoomLevel unsignedIntegerValue];
        }
        lastZoomLevel = zoomLevel;
    }
    NSLog(@"ZOOM LEVEL %@ (fall-through)", lastZoomLevel);
    return [lastZoomLevel unsignedIntegerValue];
}

-(NSUInteger)getCellSizeForScale:(double)scale {
    return [self.grids[@([self getZoomForScale:scale])][kLODLevelCellSize] unsignedIntegerValue];
}

-(BOOL)callout:(AGSCallout *)callout willShowForFeature:(id<AGSFeature>)feature layer:(AGSLayer<AGSHitTestable> *)layer mapPoint:(AGSPoint *)mapPoint {
    AGSCluster *cluster = objc_getAssociatedObject(feature, kClusterPayloadKey);
    if (cluster) {
        callout.title = @"Cluster";
        callout.detail = [NSString stringWithFormat:@"Cluster contains %d features", cluster.features.count];
        callout.accessoryButtonHidden = YES;
    } else {
        callout.title = @"Ordinary feature";
        callout.detail = @"Might have a bunch of attributes on it";
        callout.accessoryButtonHidden = NO;
    }
    return YES;
}

#pragma mark - Display Update Hooks
-(void)featuresLoaded:(NSNotification *)notification {
    NSLog(@"Features Loaded");
    [self refresh];
}

-(void)mapDidUpdate:(AGSMapUpdateType)updateType
{
    if (updateType == AGSMapUpdateTypeSpatialExtent) {
        NSLog(@"Map Extent Updated");
        self.willClusterAtCurrentScale = self.mapView.mapScale > self.minScaleForClustering;
        [self refreshClusters];
    }
    [super mapDidUpdate:updateType];
}

-(void)setWillClusterAtCurrentScale:(BOOL)willClusterAtCurrentScale {
    BOOL wasClusteringAtPreviousScale = _willClusterAtCurrentScale;
    if (willClusterAtCurrentScale != wasClusteringAtPreviousScale) {
        [self willChangeValueForKey:@"willClusterAtCurrentScale"];
    }
    _willClusterAtCurrentScale = willClusterAtCurrentScale;
    if (willClusterAtCurrentScale != wasClusteringAtPreviousScale) {
        [self didChangeValueForKey:@"willClusterAtCurrentScale"];
    }
}

-(BOOL)willClusterAtCurrentScale {
    return _willClusterAtCurrentScale;
}

+(BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"willClusterAtCurrentScale"]) {
        return NO;
    } else {
        return [super automaticallyNotifiesObserversForKey:key];
    }
}

#pragma mark - Properties
-(void)setShowClusterCoverages:(BOOL)showClusterCoverages {
    _showClusterCoverages = showClusterCoverages;
    [self refresh];
}

-(AGSEnvelope *)clustersEnvelope {
    AGSMutableEnvelope *envelope = nil;
    for (AGSCluster *cluster in self.grid.clusters) {
        AGSGeometry *coverage = cluster.coverage;
        if (!envelope) {
            envelope = [coverage.envelope mutableCopy];
        } else {
            [envelope unionWithEnvelope:coverage.envelope];
        }
    }
    return envelope;
}

#pragma mark - Layer Refresh
-(void)refresh {
    [self refreshClusters];
    [super refresh];
}

-(void)refreshClusters {
    [self clearClusters];
    [self rebuildClusterGrid];
    [self renderClusters];
}

-(void)clearClusters {
    [self removeAllGraphics];
    if (self.grid) {
        [self.grid removeAllFeatures];
    }
}

#pragma mark - Cluster Generation and Display
-(void)rebuildClusterGrid {
    NSUInteger zoomLevel = [self getZoomForScale:self.mapView.mapScale];
    self.grid = self.grids[@(zoomLevel)][kLODLevelGrid];
    
    NSDate *startTime = [NSDate date];

    [self.grid removeAllFeatures];
    [self.grid addFeatures:self.featureLayer.graphics];
    
    NSTimeInterval clusteringDuration = -[startTime timeIntervalSinceNow];
    
    NSLog(@"Rebuilt %d features into %d clusters with cell size %d in %.4fs", self.featureLayer.graphicsCount, self.grid.clusters.count, self.grid.cellSize, clusteringDuration);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AGSClusterLayerDidCompleteClusteringNotification
                                                        object:self
                                                      userInfo:@{
                                                                 kClusterNotificationUserInfoKey_Duration: @(clusteringDuration),
                                                                 kClusterNotificationUserInfoKey_ClusterCount: @(self.grid.clusters.count),
                                                                 kClusterNotificationUserInfoKey_FeatureCount: @(self.featureLayer.graphicsCount),
                                                                 kClusterNotificationUserInfoKey_CellSize: @(self.grid.cellSize)
                                                                 }];
}

-(void) renderClusters {
    NSMutableArray *coverageGraphics = [NSMutableArray array];
    NSMutableArray *clusterGraphics = [NSMutableArray array];
    NSMutableArray *featureGraphics = [NSMutableArray array];
    
    for (AGSCluster *cluster in self.grid.clusters) {
        if (self.mapView.mapScale > self.minScaleForClustering &&
            cluster.features.count >= self.minClusterCount) {
            // Draw as cluster.
            if (self.showClusterCoverages && cluster.features.count > 2) {
                AGSGraphic *coverageGraphic = [AGSGraphic graphicWithGeometry:cluster.coverage
                                                                       symbol:nil
                                                                   attributes:nil];
                objc_setAssociatedObject(coverageGraphic, kClusterPayloadKey, cluster, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                coverageGraphic.symbol = [self.renderer symbolForFeature:coverageGraphic timeExtent:nil];
                [coverageGraphics addObject:coverageGraphic];
            }
            
            cluster.symbol = [self.renderer symbolForFeature:cluster timeExtent:nil];
            [clusterGraphics addObject:cluster];
        } else {
            // Draw as feature(s).
            for (AGSGraphic *feature in cluster.features) {
                feature.symbol = [self.renderer symbolForFeature:feature timeExtent:nil];
                [featureGraphics addObject:feature];
            }
        }
    }

    [self addGraphics:coverageGraphics];
    [self addGraphics:clusterGraphics];
    [self addGraphics:featureGraphics];
}

-(NSArray *)defaultLodData {
    return @[
             @{
                 @"level": @(0),
                 @"resolution": @(156543.03392800014),
                 @"scale": @(591657527.591555)
                 },
             @{
                 @"level": @(1),
                 @"resolution": @(78271.51696399994),
                 @"scale": @(295828763.795777)
                 },
             @{
                 @"level": @(2),
                 @"resolution": @(39135.75848200009),
                 @"scale": @(147914381.897889)
                 },
             @{
                 @"level": @(3),
                 @"resolution": @(19567.87924099992),
                 @"scale": @(73957190.948944)
                 },
             @{
                 @"level": @(4),
                 @"resolution": @(9783.93962049996),
                 @"scale": @(36978595.474472)
                 },
             @{
                 @"level": @(5),
                 @"resolution": @(4891.96981024998),
                 @"scale": @(18489297.737236)
                 },
             @{
                 @"level": @(6),
                 @"resolution": @(2445.98490512499),
                 @"scale": @(9244648.868618)
                 },
             @{
                 @"level": @(7),
                 @"resolution": @(1222.992452562495),
                 @"scale": @(4622324.434309)
                 },
             @{
                 @"level": @(8),
                 @"resolution": @(611.4962262813797),
                 @"scale": @(2311162.217155)
                 },
             @{
                 @"level": @(9),
                 @"resolution": @(305.74811314055756),
                 @"scale": @(1155581.108577)
                 },
             @{
                 @"level": @(10),
                 @"resolution": @(152.87405657041106),
                 @"scale": @(577790.554289)
                 },
             @{
                 @"level": @(11),
                 @"resolution": @(76.43702828507324),
                 @"scale": @(288895.277144)
                 },
             @{
                 @"level": @(12),
                 @"resolution": @(38.21851414253662),
                 @"scale": @(144447.638572)
                 },
             @{
                 @"level": @(13),
                 @"resolution": @(19.10925707126831),
                 @"scale": @(72223.819286)
                 },
             @{
                 @"level": @(14),
                 @"resolution": @(9.554628535634155),
                 @"scale": @(36111.909643)
                 },
             @{
                 @"level": @(15),
                 @"resolution": @(4.77731426794937),
                 @"scale": @(18055.954822)
                 },
             @{
                 @"level": @(16),
                 @"resolution": @(2.388657133974685),
                 @"scale": @(9027.977411)
                 },
             @{
                 @"level": @(17),
                 @"resolution": @(1.1943285668550503),
                 @"scale": @(4513.988705)
                 },
             @{
                 @"level": @(18),
                 @"resolution": @(0.5971642835598172),
                 @"scale": @(2256.994353)
                 },
             @{
                 @"level": @(19),
                 @"resolution": @(0.29858214164761665),
                 @"scale": @(1128.497176)
                 }
             ];
}
@end