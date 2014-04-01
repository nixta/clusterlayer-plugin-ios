//
//  AGSCluster.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSCluster.h"
#import "AGSCluster_int.h"
#import "NSArray+Utils.h"

#import <objc/runtime.h>

#pragma mark - Cluster Coverage
@interface AGSClusterCoverage : AGSGraphic
@end

@implementation AGSClusterCoverage
-(BOOL)isClusterCoverage {
    return YES;
}
@end

@interface AGSCluster ()
@property (nonatomic, strong) AGSPoint *gridCentroid;
@property (nonatomic, strong) AGSGraphic *calculatedCoverageGraphic;
@property (nonatomic, strong) NSMutableArray *_clustersAndFeatures;
@property (nonatomic, assign) CGPoint cellCoordinate;
@property (nonatomic, assign, readwrite) NSUInteger displayCount;
@end

@implementation AGSCluster

#pragma mark - Constructors and Initializers
+(AGSCluster *)clusterForPoint:(AGSPoint *)point {
    return [[AGSCluster alloc] initWithPoint:point];
}

-(id)initWithPoint:(AGSPoint *)point {
    self = [self init];
    if (self) {
        self.gridCentroid = point;
        self.calculatedCoverageGraphic = [AGSGraphic graphicWithGeometry:point symbol:nil attributes:nil];
        self._clustersAndFeatures = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Add and remove features
-(void)addItem:(AGSGraphic *)item {
    [self._clustersAndFeatures addObject:item];
    [self recalculateCentroidAndCoverage];
}

-(void)addItems:(NSArray *)items {
    [self._clustersAndFeatures addObjectsFromArray:items];
    [self recalculateCentroidAndCoverage];
}

-(BOOL)removeItem:(AGSGraphic *)item {
    if ([self._clustersAndFeatures containsObject:item]) {
        [self._clustersAndFeatures removeObject:item];
        [self recalculateCentroidAndCoverage];
        return YES;
    }
    return NO;
}

-(void)clearItems {
    [self._clustersAndFeatures removeAllObjects];
    [self recalculateCentroidAndCoverage];
}

#pragma mark - Centroid logic
-(void) recalculateCentroidAndCoverage {
    if (self._clustersAndFeatures.count > 0) {
        for (AGSCluster *cluster in self.items) {
            if ([cluster isKindOfClass:[AGSCluster class]]) {
                self.displayCount += cluster.displayCount;
            } else {
                self.displayCount++;
            }
        }
        
        // Get an array of geometries from all the clusters and features
        NSArray *allGeomsForCoverage = [self._clustersAndFeatures map:^id(id obj) {
            if ([obj isKindOfClass:[AGSCluster class]]) {
                return ((AGSCluster *)obj).coverage;
            } else {
                return ((id<AGSFeature>)obj).geometry;
            }
        }];
        
        // Union and Convex Hull
        AGSGeometry *geom = [[AGSGeometryEngine defaultGeometryEngine] unionGeometries:allGeomsForCoverage];
        AGSGeometry *coverage = [[AGSGeometryEngine defaultGeometryEngine] convexHullForGeometry:geom];
        
        // Determine the centroid
        if ([coverage isKindOfClass:[AGSPolygon class]]) {
            self.calculatedCoverageGraphic.geometry = coverage;
            self.geometry = [[AGSGeometryEngine defaultGeometryEngine] labelPointForPolygon:(AGSPolygon *)self.calculatedCoverageGraphic.geometry];
        } else if ([coverage isKindOfClass:[AGSPolyline class]]) {
            AGSPolyline *cl = (AGSPolyline *)coverage;
            self.calculatedCoverageGraphic.geometry = coverage;
            AGSPoint *pt1 = [cl pointOnPath:0 atIndex:0];
            AGSPoint *pt2 = [cl pointOnPath:0 atIndex:1];
            self.geometry = [AGSPoint pointWithX:(pt1.x+pt2.x)/2
                                               y:(pt1.y+pt2.y)/2
                                spatialReference:cl.spatialReference];
        } else if ([coverage isKindOfClass:[AGSPoint class]]) {
            self.calculatedCoverageGraphic.geometry = coverage;
            self.geometry = coverage;
        }
    } else {
        self.calculatedCoverageGraphic.geometry = self.gridCentroid;
        self.geometry = self.gridCentroid;
    }
}

#pragma mark - Properties
-(NSArray *)features {
    return [self._clustersAndFeatures filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return ![evaluatedObject isKindOfClass:[AGSCluster class]];
    }]];
}

-(NSArray *)clusters {
    return [self._clustersAndFeatures filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isKindOfClass:[AGSCluster class]];
    }]];
}

-(NSArray *)items {
    return [NSArray arrayWithArray:self._clustersAndFeatures];
}

-(NSArray *)deepFeatures {
    NSMutableArray *clusterFeatures = [self.features mutableCopy];
    for (AGSCluster *childCluster in self.clusters) {
        [clusterFeatures addObjectsFromArray:[childCluster deepFeatures]];
    }
    return clusterFeatures;
}

-(AGSGraphic *)coverageGraphic {
    return [[AGSClusterCoverage alloc] initWithGeometry:self.coverage symbol:nil attributes:nil];
}

-(AGSGeometry *)coverage {
    return self.calculatedCoverageGraphic.geometry;
}
@end