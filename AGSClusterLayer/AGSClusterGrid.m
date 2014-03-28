//
//  AGSClusterDistanceGrid.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterGrid.h"
#import "AGSCluster.h"
#import "AGSCluster_int.h"
#import <objc/runtime.h>

#define kClusterKey @"_agsclusterkey"

#define kAddFeaturesArrayKey @"__tempArrayKey"

@interface AGSClusterGrid()
@property (nonatomic, assign, readwrite) NSUInteger cellSize;
@property (nonatomic, strong) NSMutableDictionary* grid;
@end

CGPoint getGridCoordForMapPoint(AGSPoint* pt, NSUInteger cellSize) {
    return CGPointMake(floor(pt.x/cellSize), floor(pt.y/cellSize));
}

AGSPoint* getGridCellCentroid(CGPoint cellCoord, NSUInteger cellSize) {
    return [AGSPoint pointWithX:(cellCoord.x * cellSize) + (cellSize/2)
                              y:cellCoord.y * cellSize + (cellSize/2)
               spatialReference:[AGSSpatialReference webMercatorSpatialReference]];
}

@implementation AGSClusterGrid
-(id)initWithCellSize:(NSUInteger)cellSize {
    self = [self init];
    if (self) {
        self.cellSize = cellSize;
        self.grid = [NSMutableDictionary dictionary];
    }
    return self;
}

-(AGSCluster *)getClusterForFeature:(id<AGSFeature>)feature {
    AGSPoint *pt = (AGSPoint *)feature.geometry;
    NSAssert(pt != nil, @"Feature Geometry is NIL!");
    CGPoint cellCoord = getGridCoordForMapPoint(pt, self.cellSize);
    
    NSMutableDictionary *row = self.grid[@(cellCoord.y)];
    if (!row) {
        row = [NSMutableDictionary dictionary];
        [self.grid setObject:row forKey:@(cellCoord.y)];
    }
    AGSCluster *cluster = row[@(cellCoord.x)];
    if (!cluster) {
        cluster = [AGSCluster clusterForPoint:getGridCellCentroid(cellCoord, self.cellSize)];
        cluster.cellCoordinate = cellCoord;
        [row setObject:cluster forKey:@(cellCoord.x)];
    }
    return cluster;
}

-(void)addFeature:(id<AGSFeature>)feature {
    AGSCluster *cluster = [self getClusterForFeature:feature];
    [cluster addFeature:feature];
}

-(void)addFeatures:(NSArray *)features {
    NSMutableSet *clustersForFeatures = [NSMutableSet set];
    for (id<AGSFeature> feature in features) {
        AGSCluster *cluster = [self getClusterForFeature:feature];
        NSMutableArray *featuresToAddToCluster = objc_getAssociatedObject(cluster, kAddFeaturesArrayKey);
        if (!featuresToAddToCluster) {
            featuresToAddToCluster = [NSMutableArray array];
            objc_setAssociatedObject(cluster, kAddFeaturesArrayKey, featuresToAddToCluster, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [featuresToAddToCluster addObject:feature];
        [clustersForFeatures addObject:cluster];
    }
    
    for (AGSCluster *cluster in clustersForFeatures) {
        NSArray *featuresToAdd = objc_getAssociatedObject(cluster, kAddFeaturesArrayKey);
        [cluster addFeatures:featuresToAdd];
        objc_setAssociatedObject(cluster, kAddFeaturesArrayKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
}

-(void)updateFeature:(id<AGSFeature>)feature {
    [self removeFeature:feature];
    [self addFeature:feature];
}

-(BOOL)removeFeature:(id<AGSFeature>)feature {
    AGSCluster *cluster = [self getClusterForFeature:feature];
    @try {
        return [cluster removeFeature:feature];
    }
    @finally {
        if (cluster.features.count == 0) {
            CGPoint cellCoord = cluster.cellCoordinate;
            NSMutableDictionary *row = self.grid[@(cellCoord.y)];
            [row removeObjectForKey:@(cellCoord.x)];
        }
    }
}

-(void)removeAllFeatures {
    for (NSMutableDictionary *row in self.grid.allValues) {
        for (AGSCluster *cluster in row.allValues) {
            [cluster clearFeatures];
        }
        [row removeAllObjects];
    }
    [self.grid removeAllObjects];
}

-(NSArray *)clusters {
    NSMutableArray *clusters = [NSMutableArray array];
    for (NSDictionary *row in self.grid.allValues) {
        for (AGSCluster *cluster in row.allValues) {
            [clusters addObject:cluster];
        }
    }
    return [NSArray arrayWithArray:clusters];
}

-(id<AGSFeature>)getFeatureNear:(AGSPoint *)mapPoint {
    double closestDistance = (double)self.cellSize;
    id closestFeature = nil;
    for (AGSCluster *cluster in self.clusters) {
        for (id<AGSFeature> feature in cluster.features) {
            double distance = [[AGSGeometryEngine defaultGeometryEngine] distanceFromGeometry:feature.geometry toGeometry:mapPoint];
            if (distance < closestDistance) {
                closestFeature = feature;
                closestDistance = distance;
            }
        }
    }
    return closestFeature;
}

-(NSString *)description {
    NSUInteger clusterCount = 0;
    NSUInteger featureCount = 0;
    NSUInteger loneFeatures = 0;
    for (AGSCluster *cluster in self.clusters) {
        if (cluster.features.count > 1) {
            clusterCount++;
        } else {
            loneFeatures++;
        }
        featureCount += cluster.features.count;
    }
    return [NSString stringWithFormat:@"Cluster Layer: %d features in %d clusters (with %d unclustered)", featureCount, clusterCount, loneFeatures];
}
@end
