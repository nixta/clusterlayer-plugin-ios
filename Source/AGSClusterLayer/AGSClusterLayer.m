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
#import "AGSClusterLayerRenderer.h"

#define kClusterPayloadKey @"__cluster"

#define kDefaultMinClusterCount 5

#import <objc/runtime.h>

@interface AGSClusterLayer () <AGSLayerCalloutDelegate>
@property (nonatomic, strong) AGSClusterGrid *grid;
@property (nonatomic, weak) AGSFeatureLayer *featureLayer;
@end

@implementation AGSClusterLayer
+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer {
    return [[AGSClusterLayer alloc] initWithFeatureLayer:featureLayer];
}

-(id)init {
    self = [super init];
    if (self) {
        self.showClusterCoverages = NO;
        self.calloutDelegate = self;
        self.minClusterCount = kDefaultMinClusterCount;
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

-(void)featureLayerLoaded:(NSNotification *)notification {
    NSLog(@"Stealing renderer...");
    self.renderer = [[AGSClusterLayerRenderer alloc] initAsSurrogateFor:self.featureLayer.renderer];
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

-(void)featuresLoaded:(NSNotification *)notification {
    NSLog(@"Features Loaded");
    [self refreshClusters];
}

-(void)mapDidUpdate:(AGSMapUpdateType)updateType
{
    if (updateType == AGSMapUpdateTypeSpatialExtent) {
        NSLog(@"Map Extent Updated");
        [self refreshClusters];
    }
    [super mapDidUpdate:updateType];
}

-(void)setShowClusterCoverages:(BOOL)showClusterCoverages {
    _showClusterCoverages = showClusterCoverages;
    [self refresh];
}

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

-(void)rebuildClusterGrid {
    NSUInteger hCells = 7;
    NSUInteger vCells = 7;
    AGSEnvelope *mapEnv = [self.mapView toMapEnvelope:CGRectMake(0, 0, self.mapView.layer.bounds.size.width/hCells, self.mapView.layer.bounds.size.height/vCells)];
    NSUInteger cellSize = floor((mapEnv.height + mapEnv.width)/2);
    self.grid = [[AGSClusterGrid alloc] initWithCellSize:cellSize];
    for (id<AGSFeature> feature in self.featureLayer.graphics) {
        [self.grid addFeature:feature];
    }
}

-(void) renderClusters {
    NSMutableArray *coverageGraphics = [NSMutableArray array];
    NSMutableArray *clusterGraphics = [NSMutableArray array];
    NSMutableArray *featureGraphics = [NSMutableArray array];
    
    for (AGSCluster *cluster in self.grid.clusters) {
        if (cluster.features.count >= self.minClusterCount) {
            // Draw as cluster.
            if (self.showClusterCoverages && cluster.features.count > 1) {
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