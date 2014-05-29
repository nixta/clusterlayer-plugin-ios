//
//  AGSClusterLayer.m
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSCL.h"
#import "AGSClusterLayer.h"
#import "AGSClusterGrid.h"
#import "AGSCluster.h"
#import "Common_int.h"
#import "NSArray+Utils.h"
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

#define kBatchQueryOperationQueryKey @"__batchquery"

NSString * const AGSClusterLayerClusteringProgressNotification = kClusterLayerClusteringNotification;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_PercentComplete = kClusterLayerClusteringNotification_Key_PercentComplete;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_TotalZoomLevels = kClusterLayerClusteringNotification_Key_TotalZoomLevels;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_CompletedZoomLevels = kClusterLayerClusteringNotification_Key_ZoomLevelsClustered;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_FeatureCount = kClusterLayerClusteringNotification_Key_FeatureCount;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_Duration = kClusterLayerClusteringNotification_Key_Duration;

NSString * const AGSClusterLayerDataLoadingErrorNotification = kClusterLayerDataLoadingErrorNotification;
NSString * const AGSClusterLayerDataLoadingErrorNotification_UserInfo_Error = kClusterLayerDataLoadingErrorNotification_Key_Error;

NSString * const AGSClusterLayerDataLoadingProgressNotification = kClusterLayerDataLoadingNotification;
NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_PercentComplete = kClusterLayerDataLoadingNotification_Key_PercentComplete;
NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_TotalRecordsToLoad = kClusterLayerDataLoadingNotification_Key_TotalRecords;
NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_RecordsLoaded = kClusterLayerDataLoadingNotification_Key_LoadedCount;

NSString * NSStringFromBool(BOOL boolValue) {
    return boolValue?@"YES":@"NO";
}

#pragma mark - Internal properties
@interface AGSClusterLayer () <AGSLayerCalloutDelegate, AGSFeatureLayerQueryDelegate>

@property (nonatomic, strong) NSMutableDictionary *grids;
@property (nonatomic, strong) NSArray *sortedGridKeys;
@property (nonatomic, strong) AGSClusterGrid *gridForCurrentScale;
@property (nonatomic, readonly) AGSClusterGrid *maxZoomLevelGrid;

@property (nonatomic, strong) NSArray *lodData;

@property (nonatomic, weak) AGSFeatureLayer *featureLayer;
@property (nonatomic, strong) NSMutableDictionary *lazyLoadParameters;
@property (nonatomic, assign, readwrite) BOOL willClusterAtCurrentScale;

@property (nonatomic, assign) BOOL loadAllFeatures;

@property (nonatomic, assign) BOOL mapViewLoaded;
@property (nonatomic, assign) BOOL dataLoaded;
@property (nonatomic, assign) BOOL initialized;

@property (nonatomic, strong) NSNumber *maxZoomLevel;

@property (nonatomic, strong) AGSGDBSyncTask *syncTask;
@property (nonatomic, assign) NSUInteger maxRecordCount;
@property (nonatomic, strong) NSMutableSet *openQueries;
@property (nonatomic, assign) NSUInteger featuresToLoad;
@property (nonatomic, assign) NSUInteger featuresToLoadTotal;
@property (nonatomic, strong) NSMutableArray *allFeatures;

@property (nonatomic, strong) NSMutableArray *clusteringGrids;
@property (nonatomic, strong) NSDate *clusteringStartTime;
@end


#pragma mark - Synthesizers
@implementation AGSClusterLayer
@synthesize willClusterAtCurrentScale = _willClusterAtCurrentScale;
@synthesize initialized = _initialized;

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
        self.dataLoaded = NO;
        self.initialized = NO;
        
        self.loadAllFeatures = YES;
        
        self.showClusterCoverages = NO;
        self.calloutDelegate = self;
        self.minClusterCount = kDefaultMinClusterCount;
        self.lazyLoadParameters = [NSMutableDictionary dictionary];
        self.minScaleForClustering  = 0;
        self.grids = [NSMutableDictionary dictionary];
        self.lodData = [self defaultLodData];
        self.openQueries = [NSMutableSet set];
        self.featuresToLoad = 0;
        self.featuresToLoadTotal = 0;
        self.allFeatures = [NSMutableArray array];
        [self parseLodData];
    }
    return self;
}

-(id)initWithFeatureLayer:(AGSFeatureLayer *)featureLayer {
    self = [self init];
    if (self) {
        self.featureLayer = featureLayer;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(featureLayerLoaded:)
                                                     name:AGSLayerDidLoadNotification
                                                   object:self.featureLayer];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(featureLayerFailedToLoad:)
                                                     name:AGSLayerDidFailToLoadNotification
                                                   object:self.featureLayer];
    }
    return self;
}

#pragma mark - Asynchronous Setup
-(void)featureLayerLoaded:(NSNotification *)notification {
    AGSClusterSymbolGeneratorBlock clusterGenBlock = self.lazyLoadParameters[kClusterRenderBlockParameterKey];
    AGSClusterSymbolGeneratorBlock coverageGenBlock = self.lazyLoadParameters[kCoverageRenderBlockParameterKey];
    self.lazyLoadParameters = nil;
    
    self.renderer = [[AGSClusterLayerRenderer alloc] initAsSurrogateFor:self.featureLayer.renderer
                                                     clusterSymbolBlock:clusterGenBlock
                                                    coverageSymbolBlock:coverageGenBlock];
    if (self.loadAllFeatures) {
        // Load all the data up-front.
        // We are then not dependent on the underlying feature layer for data updates.
        self.featureLayer.visible = NO;
        
        self.syncTask = [[AGSGDBSyncTask alloc] initWithURL:self.featureLayer.URL credential:self.featureLayer.credential];
        __weak AGSGDBSyncTask *weakTask = self.syncTask;
        __weak typeof(self) weakSelf = self;
        [self.syncTask setLoadCompletion:^(NSError *error) {
            if (error) {
                NSLog(@"Could not load FeatureServiceInfo: %@", error);
            } else {
                weakSelf.maxRecordCount = weakTask.featureServiceInfo.maxRecordCount;
                if (weakSelf.maxRecordCount == 0) {
                    weakSelf.maxRecordCount = 1000;
                }
                weakSelf.featureLayer.queryDelegate = weakSelf;
                AGSQuery *q = [AGSQuery query];
                q.where = @"1=1";
                [weakSelf.featureLayer queryIds:q];
            }
        }];
    } else {
        // Load as the underlying feature layer updates its data. We build an accumulative copy of all the data.
        self.featureLayer.opacity = 0.5;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(featuresLoaded:)
                                                     name:AGSFeatureLayerDidLoadFeaturesNotification
                                                   object:self.featureLayer];
    }
    
    [self createBlankGridsForLods];
}

-(void)featureLayerFailedToLoad:(NSNotification *)notification {
    NSLog(@"FeatureLayer failed to load: %@", self.featureLayer.error);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AGSClusterLayerDataLoadingErrorNotification
                                                        object:self
                                                      userInfo:@{kClusterLayerDataLoadingErrorNotification_Key_Error: self.featureLayer.error}];
}

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didQueryObjectIdsWithResults:(NSArray *)objectIds {
    NSUInteger count = 0;
    NSUInteger pageCount = 0;
    NSMutableArray *pagesToLoad = [NSMutableArray array];
    NSMutableArray *currentArray = nil;
    for (NSNumber *oid in objectIds) {
        if (count % self.maxRecordCount == 0) {
            currentArray = [NSMutableArray array];
            [pagesToLoad addObject:currentArray];
            pageCount++;
            // NSLog(@"Created page %d of IDs", pageCount);
        }
        [currentArray addObject:oid];
        count++;
    }
    self.featuresToLoad = count;
    self.featuresToLoadTotal = count;

    for (NSArray *featureIds in pagesToLoad) {
        AGSQuery *q = [AGSQuery query];
        q.objectIds = featureIds;
        q.returnGeometry = YES;
        NSOperation *queryOp = [self.featureLayer queryFeatures:q];
        objc_setAssociatedObject(queryOp, kBatchQueryOperationQueryKey, q, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self.openQueries addObject:queryOp];
        // NSLog(@"Fired off query %d", [pagesToLoad indexOfObject:featureIds]);
    }
}

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didFailQueryObjectIdsWithError:(NSError *)error {
    NSLog(@"Could not get object IDs to load");
}

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didQueryFeaturesWithFeatureSet:(AGSFeatureSet *)featureSet {
    [self addOrUpdateFeatures:featureSet.features];
    [self gotFeatureBlock:op];
}

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didFailQueryFeaturesWithError:(NSError *)error {
    NSLog(@"Could not load features");
    [self gotFeatureBlock:op];
}

-(void)gotFeatureBlock:(NSOperation *)op {
    AGSQuery *q = objc_getAssociatedObject(op, kBatchQueryOperationQueryKey);
    [self.openQueries removeObject:op];
    self.featuresToLoad -= q.objectIds.count;
    NSUInteger featuresLoaded = self.featuresToLoadTotal - self.featuresToLoad;
    double percentComplete = 100.0f * featuresLoaded / self.featuresToLoadTotal;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kClusterLayerDataLoadingNotification
                                                        object:self
                                                      userInfo:@{kClusterLayerDataLoadingNotification_Key_TotalRecords: @(self.featuresToLoadTotal),
                                                                 kClusterLayerDataLoadingNotification_Key_LoadedCount: @(featuresLoaded),
                                                                 kClusterLayerDataLoadingNotification_Key_PercentComplete: @(percentComplete)}];
    
    // NSLog(@"%d feature queries remaining for %d features", self.openQueries.count, self.featuresToLoad);
    if (self.openQueries.count == 0) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // NSLog(@"Done loading %d features.", self.allFeatures.count);
            self.dataLoaded = YES;
            [self rebuildClusterGrid];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self refresh];
            });
        });
    }
}

-(void)addOrUpdateFeatures:(NSArray *)features {
    [self.allFeatures addObjectsFromArray:features];
}

#pragma mark - Update Hooks
-(void)featuresLoaded:(NSNotification *)notification {
    [self addOrUpdateFeatures:self.featureLayer.graphics];
    // NSLog(@"Features Loaded: %d", newFeatures.count);
    self.dataLoaded = YES;
    [self rebuildClusterGrid];
    [self refresh];
}

-(NSString *)objectIdField {
    return self.featureLayer.objectIdField;
}

-(void)mapDidUpdate:(AGSMapUpdateType)updateType
{
    if (updateType == AGSMapUpdateTypeSpatialExtent) {
        // NSLog(@"Map Extent Updated: %@", NSStringFromBool(self.mapView.loaded));
        self.mapViewLoaded = self.mapView.loaded;
        self.willClusterAtCurrentScale = self.mapView.mapScale > self.minScaleForClustering;
        if (self.initialized) {
            self.gridForCurrentScale = [self findGridForCurrentScale];
        }
    }
    [super mapDidUpdate:updateType];
}

#pragma mark - Map/Data Load tracking
-(BOOL)initialized {
    if (!_initialized) {
        [self initializeIfPossible];
    }
    return _initialized;
}

-(void)setInitialized:(BOOL)initialized {
    _initialized = initialized;
    if (_initialized) {
        self.gridForCurrentScale = [self findGridForCurrentScale];
    }
}

-(void)initializeIfPossible {
    if (!_initialized) {
        if (self.mapViewLoaded && self.dataLoaded) {
            self.initialized = YES;
        }
    }
}

#pragma mark - Current Grid
-(void)setGridForCurrentScale:(AGSClusterGrid *)gridForCurrentScale {
    if (_gridForCurrentScale != gridForCurrentScale) {
        _gridForCurrentScale = gridForCurrentScale;
        [self refresh];
    }
}

#pragma mark - Helpers
-(NSUInteger)getZoomForScale:(double)scale {
    NSNumber *lastZoomLevel = nil;
    for (NSNumber *zoomLevel in [self.sortedGridKeys reverseObjectEnumerator]) {
        NSDictionary *d = self.grids[zoomLevel];
        double scaleForZoom = [d[kLODLevelScale] doubleValue];
        if (scale <= scaleForZoom) {
            // This is our ZoomLevel
            return [zoomLevel unsignedIntegerValue];
        }
        lastZoomLevel = zoomLevel;
    }
    return [lastZoomLevel unsignedIntegerValue];
}

-(NSUInteger)getCellSizeForScale:(double)scale {
    return [self.grids[@([self getZoomForScale:scale])][kLODLevelCellSize] unsignedIntegerValue];
}

#pragma mark - Property Overrides
-(void)setMapView:(AGSMapView *)mapView {
    [super setMapView:mapView];
    self.mapViewLoaded = self.mapView.loaded;
}

#pragma mark - Properties
-(void)setShowClusterCoverages:(BOOL)showClusterCoverages {
    _showClusterCoverages = showClusterCoverages;
    [self refresh];
}

-(AGSEnvelope *)clustersEnvelopeForZoomLevel:(NSUInteger)zoomLevel {
    AGSMutableEnvelope *envelope = nil;
    AGSClusterGrid *gridToZoomTo = self.grids[@(zoomLevel)][kLODLevelGrid];
    for (AGSCluster *cluster in gridToZoomTo.clusters) {
        AGSGeometry *coverage = cluster.coverageGraphic.geometry;
        if (!envelope) {
            envelope = [coverage.envelope mutableCopy];
        } else {
            [envelope unionWithEnvelope:coverage.envelope];
        }
    }
    return envelope;
}

-(AGSClusterGrid *)findGridForCurrentScale {
    return self.grids[@([self getZoomForScale:self.mapView.mapScale])][kLODLevelGrid];
}

-(AGSClusterGrid *)maxZoomLevelGrid {
    return self.grids[self.maxZoomLevel][kLODLevelGrid];
}

-(void)setWillClusterAtCurrentScale:(BOOL)willClusterAtCurrentScale {
    BOOL wasClusteringAtPreviousScale = _willClusterAtCurrentScale;
    if (willClusterAtCurrentScale != wasClusteringAtPreviousScale) {
        [self willChangeValueForKey:@"willClusterAtCurrentScale"];
    }
    _willClusterAtCurrentScale = willClusterAtCurrentScale;
    if (willClusterAtCurrentScale != wasClusteringAtPreviousScale) {
        [self didChangeValueForKey:@"willClusterAtCurrentScale"];
        [self refresh];
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

#pragma mark - Layer Refresh
-(void)refresh {
    if (!self.initialized) return;
    
    [self refreshClusters];
    
    [super refresh];
}

-(void)refreshClusters {
    [self removeAllGraphics];
    [self renderClusters];
}

-(void)clearClusters {
    [self removeAllGraphics];
    [self.maxZoomLevelGrid removeAllItems];
}

#pragma mark - Cluster Generation and Display
-(void)rebuildClusterGrid {
    self.clusteringStartTime = [NSDate date];
    self.clusteringGrids = [NSMutableArray arrayWithArray:[self.grids.allValues map:^id(id obj) {
        return obj[kLODLevelGrid];
    }]];
    
    AGSClusterGrid *grid = self.maxZoomLevelGrid;
    [grid addItems:self.allFeatures];
}

-(void)gridClustered:(NSNotification *)notification {
    [self.clusteringGrids removeObject:notification.object];
    
    NSUInteger gridsClustered = self.grids.count - self.clusteringGrids.count;
    NSTimeInterval clusteringDuration = -[self.clusteringStartTime timeIntervalSinceNow];
    // NSLog(@"%f", clusteringDuration);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kClusterLayerClusteringNotification
                                                            object:self
                                                          userInfo:@{
                                                                     kClusterLayerClusteringNotification_Key_Duration: @(clusteringDuration),
                                                                     kClusterLayerClusteringNotification_Key_PercentComplete: @(100*gridsClustered/self.grids.count),
                                                                     kClusterLayerClusteringNotification_Key_FeatureCount: @(self.allFeatures.count),
                                                                     kClusterLayerClusteringNotification_Key_TotalZoomLevels: @(self.grids.count),
                                                                     kClusterLayerClusteringNotification_Key_ZoomLevelsClustered: @(self.grids.count - self.clusteringGrids.count)
                                                                     }];
    });
}

-(void) renderClusters {
    NSMutableArray *coverageGraphics = [NSMutableArray array];
    NSMutableArray *clusterGraphics = [NSMutableArray array];
    NSMutableArray *featureGraphics = [NSMutableArray array];
    
    // NSLog(@"Rendering %d items at zoom level %@", self.gridForCurrentScale.clusters.count, self.gridForCurrentScale.zoomLevel);
    
    for (AGSCluster *cluster in self.gridForCurrentScale.clusters) {
        // NSLog(@"Cluster: %@", cluster);
        if (self.mapView.mapScale > self.minScaleForClustering &&
            cluster.displayCount >= self.minClusterCount) {
            // Draw as cluster.
            if (self.showClusterCoverages && cluster.features.count > 2) {
                // Draw the coverage if need be
                AGSGraphic *coverageGraphic = cluster.coverageGraphic;
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

#pragma mark - UI/Callouts
-(BOOL)callout:(AGSCallout *)callout willShowForFeature:(id<AGSFeature>)feature layer:(AGSLayer<AGSHitTestable> *)layer mapPoint:(AGSPoint *)mapPoint {
    if ([feature isMemberOfClass:[AGSCluster class]]) {
        AGSCluster *cluster = (AGSCluster*)feature;
        NSLog(@"%@ :: %d", cluster, cluster.displayCount);
        if (cluster) {
            callout.title = @"Cluster";
            callout.detail = [NSString stringWithFormat:@"Cluster contains %d features", cluster.features.count];
            callout.accessoryButtonHidden = YES;
        }
    } else {
        callout.title = @"Ordinary feature";
        callout.detail = @"Might have a bunch of attributes on it";
        callout.accessoryButtonHidden = NO;
    }
    return YES;
}

#pragma mark - Build All Grids
-(void)createBlankGridsForLods {
    CGFloat cellSizeInInches = 0.25;
    AGSUnits mapUnits = self.mapViewLoaded?AGSUnitsFromSpatialReference(self.mapView.spatialReference):AGSUnitsMeters;
    AGSUnits screenUnits = AGSUnitsInches;
    double cellSizeInMapUnits = AGSUnitsToUnits(cellSizeInInches, screenUnits, mapUnits);
    
    AGSClusterGrid *prevClusterGrid = nil;
    for (NSNumber *zoomLevel in self.sortedGridKeys) {
        NSMutableDictionary *d = self.grids[zoomLevel];
        double scale = [d[kLODLevelScale] doubleValue];
        NSUInteger cellSize = floor(cellSizeInMapUnits * scale);
        d[kLODLevelCellSize] = @(cellSize);
        
        AGSClusterGrid *gridForZoomLevel = [[AGSClusterGrid alloc] initWithCellSize:cellSize forClusterLayer:self];
        gridForZoomLevel.zoomLevel = zoomLevel;
        
        prevClusterGrid.gridForNextZoomLevel = gridForZoomLevel;
        gridForZoomLevel.gridForPrevZoomLevel = prevClusterGrid;
        
        d[kLODLevelGrid] = gridForZoomLevel;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridClustered:)
                                                     name:AGSClusterGridClusteredNotification
                                                   object:gridForZoomLevel];
        
        prevClusterGrid = gridForZoomLevel;
        self.maxZoomLevel = zoomLevel;
    }
}

#pragma mark - Demo LODs
-(void)parseLodData {
    for (NSDictionary *lodInfo in self.lodData) {
        [self.grids setObject:[NSMutableDictionary dictionaryWithDictionary:lodInfo]
                       forKey:lodInfo[kLODLevelZoomLevel]];
    }
    self.sortedGridKeys = [self.grids.allKeys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [((NSNumber *)obj1) compare:obj2];
    }];
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