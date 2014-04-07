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

#import "Common.h"

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
@property (nonatomic, strong) NSMutableDictionary *_features;
@property (nonatomic, strong) NSMutableDictionary *_clusters;
@property (nonatomic, assign) CGPoint cellCoordinate;
@property (nonatomic, assign, readwrite) NSUInteger displayCount;
@property (nonatomic, assign) NSUInteger clusterId;
@end

@implementation AGSCluster

#pragma mark - Constructors and Initializers
+(AGSCluster *)clusterForPoint:(AGSPoint *)point {
    return [[AGSCluster alloc] initWithPoint:point];
}

+(NSUInteger)nextClusterId {
    static NSUInteger clusterId = 0;
    return clusterId++;
}

-(id)initWithPoint:(AGSPoint *)point {
    self = [self init];
    if (self) {
        self.gridCentroid = point;
        self.calculatedCoverageGraphic = [AGSGraphic graphicWithGeometry:point symbol:nil attributes:nil];
        self._features = [NSMutableDictionary dictionary];
        self._clusters = [NSMutableDictionary dictionary];
        self.clusterId = [AGSCluster nextClusterId];
    }
    return self;
}

#pragma mark - Add and remove features
-(void)addItem:(AGSClusterItem *)item {
    [self _addItem:item];
    [self recalculateCentroidAndCoverage];
}

-(void)addItems:(NSArray *)items {
    for (AGSClusterItem *item in items) {
        [self _addItem:item];
    }
    [self recalculateCentroidAndCoverage];
}

-(void)_addItem:(AGSClusterItem *)item {
    NSMutableDictionary *destDictionary = [self containerForItem:item];
    id key = item.clusterItemKey;
//    if ([key isEqualToString:@"f0"]) {
//        NSLog(@"Break here");
//    }
    destDictionary[key] = item;
}

-(BOOL)removeItem:(AGSClusterItem *)item {
    NSMutableDictionary *destDictionary = [self containerForItem:item];
    if ([destDictionary objectForKey:item.clusterItemKey]) {
        [destDictionary removeObjectForKey:item.clusterItemKey];
        [self recalculateCentroidAndCoverage];
        return YES;
    }
    return NO;
}

-(void)clearItems {
    [self._features removeAllObjects];
    [self._clusters removeAllObjects];
    [self recalculateCentroidAndCoverage];
}

-(NSMutableDictionary *)containerForItem:(AGSClusterItem *)item {
    return [item isMemberOfClass:[AGSCluster class]]?self._clusters:self._features;
}

-(NSUInteger)calculatedFeatureCount {
    NSUInteger myCount = 0;
    for (AGSClusterItem *child in self.items) {
        if ([child isMemberOfClass:[AGSCluster class]])
        {
            myCount += [((AGSCluster*)child) calculatedFeatureCount];
        }
        else
        {
            myCount += 1;
        }
    }
    return myCount;
}

#pragma mark - Centroid logic
-(void) recalculateCentroidAndCoverage {
    self.displayCount = self._features.count;
    if (self._clusters.count + self._features.count > 0) {
        for (AGSCluster *cluster in self._clusters.allValues) {
            self.displayCount += cluster.displayCount;
        }

        // Get an array of geometries from all the clusters and features
        NSArray *allGeomsForCoverage = [[self._clusters.allValues map:^id(id obj) {
            return ((AGSCluster *)obj).coverage;
        }] arrayByAddingObjectsFromArray:[self._features.allValues map:^id(id obj) {
            return ((AGSClusterItem *)obj).geometry;
        }]];

        // Union and Convex Hull
        AGSGeometry *geom = [[AGSGeometryEngine defaultGeometryEngine] unionGeometries:allGeomsForCoverage];
        AGSGeometry *coverage = [[AGSGeometryEngine defaultGeometryEngine] convexHullForGeometry:geom];
        
        // Determine the centroid
        switch (AGSGeometryTypeForGeometry(coverage)) {
            case AGSGeometryTypePolygon:
                self.calculatedCoverageGraphic.geometry = coverage;
                self.geometry = [[AGSGeometryEngine defaultGeometryEngine] labelPointForPolygon:(AGSPolygon *)self.calculatedCoverageGraphic.geometry];
                break;

            case AGSGeometryTypePolyline:
            {
                AGSPolyline *cl = (AGSPolyline *)coverage;
                self.calculatedCoverageGraphic.geometry = coverage;
                AGSPoint *pt1 = [cl pointOnPath:0 atIndex:0];
                AGSPoint *pt2 = [cl pointOnPath:0 atIndex:1];
                self.geometry = [AGSPoint pointWithX:(pt1.x+pt2.x)/2
                                                   y:(pt1.y+pt2.y)/2
                                    spatialReference:cl.spatialReference];
            }
                break;
             
            case AGSGeometryTypeMultipoint:
                if (((AGSMultipoint *)geom).numPoints > 1) {
                    NSLog(@"Break here");
                } else {
                    coverage = [((AGSMultipoint *)geom) pointAtIndex:0];
                }
            case AGSGeometryTypePoint:
                self.calculatedCoverageGraphic.geometry = coverage;
                self.geometry = coverage;
                break;
                
            default:
                @throw [NSException exceptionWithName:@"UnknownGeometryType"
                                               reason:@"Geometry Type Unknown!"
                                             userInfo:@{@"geomType": AGSGeometryTypeString(AGSGeometryTypeForGeometry(coverage))}];
        }
    } else {
        self.calculatedCoverageGraphic.geometry = self.gridCentroid;
        self.geometry = self.gridCentroid;
    }
}

#pragma mark - Properties
-(NSArray *)features {
    NSMutableArray *allFeatures = [NSMutableArray arrayWithArray:self._features.allValues];
    for (AGSCluster *childCluster in self.clusters) {
        [allFeatures addObjectsFromArray:childCluster.features];
    }
    return allFeatures;
}

-(NSArray *)clusters {
    return self._clusters.allValues;
}

-(NSArray *)items {
    return [[self features] arrayByAddingObjectsFromArray:[self clusters]];
}

-(NSUInteger)featureId {
    return self.clusterId;
}

-(id)clusterItemKey {
    return [NSString stringWithFormat:@"c%d", self.featureId];
}

-(AGSGraphic *)coverageGraphic {
    return [[AGSClusterCoverage alloc] initWithGeometry:self.coverage symbol:nil attributes:nil];
}

-(AGSGeometry *)coverage {
    return self.calculatedCoverageGraphic.geometry;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"Cluster %d (%d features, %d child clusters)", self.clusterId, self._features.count, self._clusters.count];
}
@end