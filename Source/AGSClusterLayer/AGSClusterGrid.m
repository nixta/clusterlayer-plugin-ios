//
//  AGSClusterDistanceGrid.m
//  AGSCluseterLayer
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterGrid.h"
#import "AGSCluster.h"
#import <objc/runtime.h>

#define kClusterKey @"_agsclusterkey"

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
    CGPoint cellCoord = getGridCoordForMapPoint(pt, self.cellSize);
    
    NSMutableDictionary *row = self.grid[@(cellCoord.y)];
    if (!row) {
        row = [NSMutableDictionary dictionary];
        [self.grid setObject:row forKey:@(cellCoord.y)];
    }
    AGSCluster *cluster = row[@(cellCoord.x)];
    if (!cluster) {
        cluster = [AGSCluster clusterForPoint:getGridCellCentroid(cellCoord, self.cellSize)];
        [row setObject:cluster forKey:@(cellCoord.x)];
    }
//    NSLog(@"Got cluster (%f,%f) for point (%f,%f)", cellCoord.x, cellCoord.y, pt.x, pt.y);
    return cluster;
}

-(void)addFeature:(id<AGSFeature>)feature {
    AGSCluster *cluster = [self getClusterForFeature:feature];
    [cluster addFeature:feature];
}

-(void)updateFeature:(id<AGSFeature>)feature {
    [self removeFeature:feature];
    [self addFeature:feature];
}

-(BOOL)removeFeature:(id<AGSFeature>)feature {
    AGSCluster *cluster = [self getClusterForFeature:feature];
    return [cluster removeFeature:feature];
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
    for (AGSCluster *cluster in self.clusters) {
        clusterCount += 1;
        featureCount += cluster.features.count;
    }
    return [NSString stringWithFormat:@"Cluster Layer: %d features in %d clusters", featureCount, clusterCount];
}
@end
