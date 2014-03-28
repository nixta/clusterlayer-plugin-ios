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

#define kClusterPayloadKey @"__cluster"
#define kClusterRenderBlockParameterKey @"clusterBlock"
#define kCoverageRenderBlockParameterKey @"coverageBlock"

#define kDefaultMinClusterCount 2

#import <objc/runtime.h>

@interface AGSClusterLayer () <AGSLayerCalloutDelegate>
@property (nonatomic, strong) AGSClusterGrid *grid;
@property (nonatomic, weak) AGSFeatureLayer *featureLayer;
@property (nonatomic, strong) NSMutableDictionary *lazyLoadParameters;
@property (nonatomic, assign, readwrite) BOOL willClusterAtCurrentScale;
@end

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
        self.showClusterCoverages = NO;
        self.calloutDelegate = self;
        self.minClusterCount = kDefaultMinClusterCount;
        self.lazyLoadParameters = [NSMutableDictionary dictionary];
        self.minScaleForClustering  = 0;
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
    }
    return self;
}

#pragma mark - Asynchronous Setup
-(void)featureLayerLoaded:(NSNotification *)notification {
    NSLog(@"Stealing renderer...");
    AGSClusterSymbolGeneratorBlock clusterGenBlock = self.lazyLoadParameters[kClusterRenderBlockParameterKey];
    AGSClusterSymbolGeneratorBlock coverageGenBlock = self.lazyLoadParameters[kCoverageRenderBlockParameterKey];
    self.renderer = [[AGSClusterLayerRenderer alloc] initAsSurrogateFor:self.featureLayer.renderer
                                                     clusterSymbolBlock:clusterGenBlock
                                                    coverageSymbolBlock:coverageGenBlock];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(featuresLoaded:)
                                                 name:AGSFeatureLayerDidLoadFeaturesNotification
                                               object:self.featureLayer];
    self.featureLayer.opacity = 0;
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
    [self refreshClusters];
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
    NSUInteger hCells = 7;
    NSUInteger vCells = 7;
    AGSEnvelope *mapEnv = [self.mapView toMapEnvelope:CGRectMake(0, 0, self.mapView.layer.bounds.size.width/hCells, self.mapView.layer.bounds.size.height/vCells)];
    NSUInteger cellSize = floor((mapEnv.height + mapEnv.width)/2);
    self.grid = [[AGSClusterGrid alloc] initWithCellSize:cellSize];
    for (id<AGSFeature> feature in self.featureLayer.graphics) {
        [self.grid addFeature:feature];
    }
    NSLog(@"Rebuilt %d features into %d clusters with cell size %d", self.featureLayer.graphicsCount, self.grid.clusters.count, cellSize);
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
            
            AGSGraphic *clusterGraphic = [AGSGraphic graphicWithGeometry:cluster.location
                                                                  symbol:nil
                                                              attributes:nil];
            objc_setAssociatedObject(clusterGraphic, kClusterPayloadKey, cluster, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            clusterGraphic.symbol = [self.renderer symbolForFeature:clusterGraphic timeExtent:nil];
            [clusterGraphics addObject:clusterGraphic];
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
@end