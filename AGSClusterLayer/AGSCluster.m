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

@interface AGSCluster ()
@property (nonatomic, strong) AGSPoint *gridCentroid;
@property (nonatomic, strong) AGSGeometry *calculatedCoverage;
@property (nonatomic, strong) NSMutableArray *_clustersAndFeatures;
@end

@implementation AGSCluster {
    CGPoint _cellCoordinate;
}

#pragma mark - Constructors and Initializers
+(AGSCluster *)clusterForPoint:(AGSPoint *)point {
    return [[AGSCluster alloc] initWithPoint:point];
}

-(id)initWithPoint:(AGSPoint *)point {
    self = [self init];
    if (self) {
        self.gridCentroid = point;
        self.calculatedCoverage = point;
        self._clustersAndFeatures = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Add and remove features
-(void)addFeature:(id<AGSFeature>)feature {
    [self._clustersAndFeatures addObject:feature];
    [self recalculateCentroidAndCoverage];
}

-(void)addFeatures:(NSArray *)features {
    [self._clustersAndFeatures addObjectsFromArray:features];
    [self recalculateCentroidAndCoverage];
}

-(BOOL)removeFeature:(id<AGSFeature>)feature {
    if ([self._clustersAndFeatures containsObject:feature]) {
        [self._clustersAndFeatures removeObject:feature];
        [self recalculateCentroidAndCoverage];
        return YES;
    }
    return NO;
}

-(void)clearFeatures {
    [self._clustersAndFeatures removeAllObjects];
    [self recalculateCentroidAndCoverage];
}

#pragma mark - Centroid logic
-(void) recalculateCentroidAndCoverage {
    if (self._clustersAndFeatures.count > 0) {
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
            self.calculatedCoverage = coverage;
            self.geometry = [[AGSGeometryEngine defaultGeometryEngine] labelPointForPolygon:(AGSPolygon *)self.calculatedCoverage];
        } else if ([coverage isKindOfClass:[AGSPolyline class]]) {
            AGSPolyline *cl = (AGSPolyline *)coverage;
            AGSPoint *pt1 = [cl pointOnPath:0 atIndex:0];
            AGSPoint *pt2 = [cl pointOnPath:0 atIndex:1];
            AGSMutablePolygon *p = [[AGSMutablePolygon alloc] initWithSpatialReference:cl.spatialReference];
            [p addRingToPolygon];
            [p addPointToRing:pt1];
            [p addPointToRing:pt2];
            [p closePolygon];
            self.calculatedCoverage = p;
            self.geometry = [AGSPoint pointWithX:(pt1.x+pt2.x)/2
                                               y:(pt1.y+pt2.y)/2
                                spatialReference:cl.spatialReference];
        } else if ([coverage isKindOfClass:[AGSPoint class]]) {
            self.calculatedCoverage = coverage;
            self.geometry = coverage;
        }
    } else {
        self.calculatedCoverage = self.gridCentroid;
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

-(AGSGeometry *)coverage {
    return self.calculatedCoverage;
}

-(CGPoint)cellCoordinate {
    return _cellCoordinate;
}

-(void)setCellCoordinate:(CGPoint)cellCoordinate {
    _cellCoordinate = cellCoordinate;
}
@end