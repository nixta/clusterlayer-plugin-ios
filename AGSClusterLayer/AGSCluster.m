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
#import "AGSGraphic+AGSClustering.h"

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
@property (nonatomic, assign) NSUInteger clusterId;
@property (nonatomic, assign) CGPoint cellCoordinate;

@property (nonatomic, strong) NSMutableArray *_int_features;
@property (nonatomic, strong) NSMutableArray *_int_clusters;
@property (nonatomic, strong) AGSCluster *parentCluster;

@property (nonatomic, strong, readwrite) AGSGeometry *coverage;
@property (nonatomic, strong, readwrite) AGSGraphic *coverageGraphic;

@property (nonatomic, assign) BOOL isDirty;
@property (nonatomic, assign) BOOL isCoverageDirty;

@property (nonatomic, assign, readwrite) NSUInteger displayCount;
@end

@implementation AGSCluster
@synthesize coverage = _coverage;
@synthesize coverageGraphic = _coverageGraphic;

#pragma mark - Initializers
-(id)initWithPoint:(AGSPoint *)point {
    self = [self init];
    if (self) {
        self.isDirty = NO;
        self.isCoverageDirty = NO;

        self.geometry = point;

        self._int_features = [NSMutableArray array];
        self._int_clusters = [NSMutableArray array];
        
        self.clusterId = [AGSCluster nextClusterId];
        
    }
    return self;
}

#pragma mark - Convenience constructors
+(AGSCluster *)clusterForPoint:(AGSPoint *)point {
    return [[AGSCluster alloc] initWithPoint:point];
}

+(NSUInteger)nextClusterId {
    static NSUInteger clusterId = 0;
    return clusterId++;
}

#pragma mark - Override Properties
-(NSUInteger)featureId {
    return self.clusterId;
}

#pragma mark - Properties
-(id)clusterItemKey {
    return [NSString stringWithFormat:@"c%d", self.featureId];
}

-(NSArray *)items {
    return [self.features arrayByAddingObjectsFromArray:self.clusters];
}

-(NSArray *)features {
    return self._int_features;
}

-(NSArray *)clusters {
    return self._int_clusters;
}

-(NSUInteger)displayCount {
    return self.features.count;
}

-(void)setIsDirty:(BOOL)isDirty {
    _isDirty = isDirty;
    if (_isDirty) {
        self.isCoverageDirty = YES;
    }
}

-(BOOL)isCluster {
    return YES;
}

#pragma mark - Geometry and Coverage
-(void)setGeometry:(AGSGeometry *)geometry {
    [super setGeometry:geometry];
    self.isDirty = NO;
}

-(AGSGeometry *)coverage {
    if (self.isCoverageDirty) {
        [self recalculateCoverage];
    }
    return _coverage;
}

-(void)setCoverage:(AGSGeometry *)coverage {
    _coverage = coverage;
}

-(AGSGraphic *)coverageGraphic {
//    static dispatch_once_t token;
    if (!_coverageGraphic) {
        _coverageGraphic = [AGSGraphic graphicWithGeometry:self.coverage symbol:nil attributes:nil];
    }
    return _coverageGraphic;
}

#pragma mark - Add and remove features
-(void)addItem:(AGSClusterItem *)item {
    [self _addItem:item];
    [self recalculateCentroid];
}

-(void)addItems:(NSArray *)items {
    for (AGSClusterItem *item in items) {
        [self _addItem:item];
    }
    [self recalculateCentroid];
}

-(void)removeItem:(AGSClusterItem *)item {
    [self _removeItem:item];
    [self recalculateCentroid];
}

-(void)clearItems {
    [self._int_features removeAllObjects];
    [self._int_clusters removeAllObjects];
    self.isDirty = YES;
    [self recalculateCentroid];
}

#pragma mark - Add and remove features (internal methods for iteration)
-(void)_addItem:(AGSClusterItem *)item {
    if (item.isCluster) {
        ((AGSCluster *)item).parentCluster = self;
        [self._int_clusters addObject:item];
        [self._int_features addObjectsFromArray:((AGSCluster *)item).features];
    } else {
        [self._int_features addObject:item];
    }
    self.isDirty = YES;
}

-(void)_removeItem:(AGSClusterItem *)item {
    if (item.isCluster) {
        ((AGSCluster *)item).parentCluster = nil;
        [self._int_clusters removeObject:item];
        [self._int_features removeObjectsInArray:((AGSCluster *)item).features];
    } else {
        [self._int_features removeObject:item];
    }
    self.isDirty = YES;
}

#pragma mark - Centroid logic
-(void) recalculateCentroid {
    if (!self.isDirty) return;
    
    double xTotal = 0, yTotal = 0;
    AGSSpatialReference *ref = nil;
    NSArray *items = self.items;
    for (AGSClusterItem *item in items) {
        AGSPoint *pt = (AGSPoint *)item.geometry;
        xTotal += pt.x;
        yTotal += pt.y;
        if (!ref) ref = pt.spatialReference;
    }
//    NSLog(@"Calculated centroid from %d points", items.count);
    AGSPoint *centroid = [AGSPoint pointWithX:xTotal/items.count y:yTotal/items.count spatialReference:ref];
    self.geometry = centroid;
    self.isDirty = NO;
}

-(void) recalculateCoverage {
    NSArray *allGeomsForCoverage = [self.features map:^id(id obj) {
        return ((AGSClusterItem *)obj).geometry;
    }];
    AGSGeometry *geom = [[AGSGeometryEngine defaultGeometryEngine] unionGeometries:allGeomsForCoverage];
    AGSGeometry *coverage = [[AGSGeometryEngine defaultGeometryEngine] convexHullForGeometry:geom];

    self.coverage = coverage;
    self.isCoverageDirty = NO;
}

//    switch (AGSGeometryTypeForGeometry(coverage)) {
//        case AGSGeometryTypePolygon:
//            self.coverage = coverage;
//            break;
//            
//        case AGSGeometryTypePolyline:
//        {
//            AGSPolyline *cl = (AGSPolyline *)coverage;
//            self.calculatedCoverageGraphic.geometry = coverage;
//            AGSPoint *pt1 = [cl pointOnPath:0 atIndex:0];
//            AGSPoint *pt2 = [cl pointOnPath:0 atIndex:1];
//            self.geometry = [AGSPoint pointWithX:(pt1.x+pt2.x)/2
//                                               y:(pt1.y+pt2.y)/2
//                                spatialReference:cl.spatialReference];
//        }
//            break;
//            
//        case AGSGeometryTypeMultipoint:
//            if (((AGSMultipoint *)geom).numPoints > 1) {
//                NSLog(@"Break here");
//            } else {
//                coverage = [((AGSMultipoint *)geom) pointAtIndex:0];
//            }
//        case AGSGeometryTypePoint:
//            self.calculatedCoverageGraphic.geometry = coverage;
//            self.geometry = coverage;
//            break;
//            
//        default:
//            @throw [NSException exceptionWithName:@"UnknownGeometryType"
//                                           reason:@"Geometry Type Unknown!"
//                                         userInfo:@{@"geomType": AGSGeometryTypeString(AGSGeometryTypeForGeometry(coverage))}];
//    }

//    if (childCount == 1) {
//        // Super Simple. Inherit the location and coverage of the child.
//        self.geometry = [((NSDictionary *)(self._clusters.count==1?self._clusters:self._features)).allValues[0] geometry];
//    }
//    if (self._clusters.count + self._features.count > 0) {
//        // Get an array of geometries from all the clusters and features
//        NSArray *allGeomsForCoverage = [[self._clusters.allValues map:^id(id obj) {
//            return ((AGSCluster *)obj).coverage;
//        }] arrayByAddingObjectsFromArray:[self._features.allValues map:^id(id obj) {
//            return ((AGSClusterItem *)obj).geometry;
//        }]];
//        
//        // Union and Convex Hull
//        AGSGeometry *geom = [[AGSGeometryEngine defaultGeometryEngine] unionGeometries:allGeomsForCoverage];
//        AGSGeometry *coverage = [[AGSGeometryEngine defaultGeometryEngine] convexHullForGeometry:geom];
    
        // Determine the centroid
//        switch (AGSGeometryTypeForGeometry(coverage)) {
//            case AGSGeometryTypePolygon:
//                self.coverage = coverage;
//                self.geometry = [[AGSGeometryEngine defaultGeometryEngine] labelPointForPolygon:(AGSPolygon *)self.calculatedCoverageGraphic.geometry];
//                break;
//                
//            case AGSGeometryTypePolyline:
//            {
//                AGSPolyline *cl = (AGSPolyline *)coverage;
//                self.calculatedCoverageGraphic.geometry = coverage;
//                AGSPoint *pt1 = [cl pointOnPath:0 atIndex:0];
//                AGSPoint *pt2 = [cl pointOnPath:0 atIndex:1];
//                self.geometry = [AGSPoint pointWithX:(pt1.x+pt2.x)/2
//                                                   y:(pt1.y+pt2.y)/2
//                                    spatialReference:cl.spatialReference];
//            }
//                break;
//                
//            case AGSGeometryTypeMultipoint:
//                if (((AGSMultipoint *)geom).numPoints > 1) {
//                    NSLog(@"Break here");
//                } else {
//                    coverage = [((AGSMultipoint *)geom) pointAtIndex:0];
//                }
//            case AGSGeometryTypePoint:
//                self.calculatedCoverageGraphic.geometry = coverage;
//                self.geometry = coverage;
//                break;
//                
//            default:
//                @throw [NSException exceptionWithName:@"UnknownGeometryType"
//                                               reason:@"Geometry Type Unknown!"
//                                             userInfo:@{@"geomType": AGSGeometryTypeString(AGSGeometryTypeForGeometry(coverage))}];
//        }
//    } else {
//        self.calculatedCoverageGraphic.geometry = self.gridCentroid;
//        self.geometry = self.gridCentroid;
//    }
//}

#pragma mark - Description Override
-(NSString *)description {
    return [NSString stringWithFormat:@"Cluster %d (%d features, %d child clusters)", self.clusterId, self._int_features.count, self._int_clusters.count];
}
@end