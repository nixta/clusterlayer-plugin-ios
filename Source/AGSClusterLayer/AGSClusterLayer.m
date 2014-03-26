//
//  AGSClusterLayer.m
//  AGSCluseterLayer
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterLayer.h"
#import "AGSClusterGrid.h"
#import "AGSCluster.h"
#import "AGSClusterLayerRenderer.h"

#import <objc/runtime.h>

@interface AGSClusterLayer () <AGSLayerCalloutDelegate>
@property (nonatomic, strong) AGSClusterGrid *grid;
@property (nonatomic, weak) AGSFeatureLayer *featureLayer;
@property (nonatomic, strong) NSMutableArray *features;
@property (nonatomic, strong) NSMutableArray *dataOperations;
@end

@implementation AGSClusterLayer
+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer {
    return [[AGSClusterLayer alloc] initWithFeatureLayer:featureLayer];
}

-(id)init {
    self = [super init];
    if (self) {
        self.features = [NSMutableArray array];
        self.dataOperations = [NSMutableArray array];
        self.showClusterCoverages = NO;
        self.calloutDelegate = self;
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

-(BOOL)callout:(AGSCallout *)callout willShowForFeature:(id<AGSFeature>)feature layer:(AGSLayer<AGSHitTestable> *)layer mapPoint:(AGSPoint *)mapPoint {
    AGSCluster *cluster = nil;
    BOOL isCoverage = NO;
    if ([feature.geometry isKindOfClass:[AGSPoint class]]) {
        cluster = objc_getAssociatedObject(feature, @"__cluster");
    } else if ([feature.geometry isKindOfClass:[AGSPolygon class]]) {
        cluster = objc_getAssociatedObject(feature, @"__cluster");
        isCoverage = YES;
    }
    if (cluster) {
        if (cluster.features.count > 1) {
            callout.title = [NSString stringWithFormat:@"Cluster%@", isCoverage?@" Polygon":@""];
            callout.detail = [NSString stringWithFormat:@"Cluster contains %d features", cluster.features.count];
        } else {
            callout.title = [NSString stringWithFormat:@"Ordinary feature"];
            callout.detail = [NSString stringWithFormat:@"Might have a bunch of attributes on it"];
        }
        return YES;
    }
    return NO;
}

-(void)setMapView:(AGSMapView *)mapView
{
    NSLog(@"Map View Set");
    [super setMapView:mapView];
}

-(void)featureLayerLoaded:(NSNotification *)notification {
    NSLog(@"Stealing renderer...");
    self.renderer = [[AGSClusterLayerRenderer alloc] initAsSurrogateFor:self.featureLayer.renderer];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(featuresLoaded:)
                                                 name:AGSFeatureLayerDidLoadFeaturesNotification
                                               object:self.featureLayer];
}

-(void)featuresLoaded:(NSNotification *)notification {
    NSLog(@"Features Loaded");
    [self clearClusters];
    [self recalcClusterGrid];
    [self renderClusters];
}

-(void)mapDidUpdate:(AGSMapUpdateType)updateType
{
    if (updateType == AGSMapUpdateTypeSpatialExtent) {
        NSLog(@"Map Extent Updated");
//        BOOL activeOperations = ![[self.featureLayer performSelector:@selector(queryOperation)] isFinished];
//        NSLog(@"Map Updated: %@", activeOperations?@"Still Loading":@"Done Loading");
//        if (!activeOperations) {
        [self clearClusters];
        [self recalcClusterGrid];
        [self renderClusters];
//        }
    }
    [super mapDidUpdate:updateType];
}

-(void)recalcClusterGrid {
    NSUInteger hCells = 7;
    NSUInteger vCells = 12;
    AGSEnvelope *mapEnv = [self.mapView toMapEnvelope:CGRectMake(0, 0, self.mapView.layer.bounds.size.width/hCells, self.mapView.layer.bounds.size.height/vCells)];
    NSUInteger cellSize = floor((mapEnv.height + mapEnv.width)/2);
    self.grid = [[AGSClusterGrid alloc] initWithCellSize:cellSize];
    for (id<AGSFeature> feature in self.featureLayer.graphics) {
        [self.grid addFeature:feature];
    }
}

-(void)clearClusters {
    [self removeAllGraphics];
    if (self.grid) {
        [self.grid removeAllFeatures];
    }
}

-(void) renderClusters {
    NSMutableArray *coverageGraphics = [NSMutableArray array];
    NSMutableArray *clusterGraphics = [NSMutableArray array];
    
    for (AGSCluster *cluster in self.grid.clusters) {
        if (self.showClusterCoverages && cluster.features.count > 1) {
            AGSGraphic *coverageGraphic = [AGSGraphic graphicWithGeometry:cluster.coverage
                                                                   symbol:nil
                                                               attributes:nil];
            coverageGraphic.symbol = [self.renderer symbolForFeature:coverageGraphic timeExtent:nil];
            objc_setAssociatedObject(coverageGraphic, @"__cluster", cluster, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [coverageGraphics addObject:coverageGraphic];
        }

        AGSGraphic *clusterGraphic = [AGSGraphic graphicWithGeometry:cluster.location
                                                              symbol:nil
                                                          attributes:nil];
        objc_setAssociatedObject(clusterGraphic, @"__cluster", cluster, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        clusterGraphic.symbol = [self.renderer symbolForFeature:clusterGraphic timeExtent:nil];
        [clusterGraphics addObject:clusterGraphic];
    }
    
    [self addGraphics:coverageGraphics];
    [self addGraphics:clusterGraphics];
}
@end