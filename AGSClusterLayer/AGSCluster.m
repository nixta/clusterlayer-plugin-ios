//
//  AGSCluster.m
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSCluster.h"
#import "AGSCluster_int.h"
#import "NSArray+Utils.h"
#import "AGSGraphic+AGSClustering.h"
#import "Common_int.h"
#import <objc/runtime.h>

@interface AGSCluster ()
@property (nonatomic, assign, readwrite) NSUInteger featureCount;

@property (nonatomic, strong) AGSClusterGrid *parentGrid;
@property (nonatomic, strong) AGSCluster *parentCluster;

@property (nonatomic, assign) NSUInteger clusterId;
@property (nonatomic, assign) CGPoint cellCoordinate;

@property (nonatomic, strong) NSMutableArray *_int_clusters;
@property (nonatomic, strong) NSMutableArray *_int_features;

@property (nonatomic, strong, readwrite) AGSGeometry *coverage;
@property (nonatomic, strong, readwrite) AGSGraphic *coverageGraphic;

@property (nonatomic, assign) BOOL isDirty;
@property (nonatomic, assign) BOOL isCoverageDirty;

@end

@implementation AGSCluster
@synthesize coverage = _coverage;
@synthesize coverageGraphic = _coverageGraphic;

#pragma mark - Initializers

-(id)initWithPoint:(AGSPoint *)point {
    self = [self init];
    if (self) {
	
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

-(NSArray *)features {
    return self._int_features;
}

-(NSArray *)childClusters {
    return self._int_clusters;
}

-(NSUInteger)featureCount {
    return self.features.count;
}

-(void)setIsDirty:(BOOL)isDirty {
    _isDirty = isDirty;
    if (_isDirty) {
        self.isCoverageDirty = YES;
    }
}

#pragma mark - Category Override
-(BOOL)isCluster {
    return YES;
}

#pragma mark - Geometry and Coverage
-(AGSGeometry *)geometry {
    if (self.isDirty) {
        [self recalculateCentroid];
    }
    return super.geometry;
}

-(void)setGeometry:(AGSGeometry *)geometry {
    [super setGeometry:geometry];
    self.isDirty = NO;
}

-(AGSEnvelope *)envelope {
    return self.coverage.envelope;
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
    if (!_coverageGraphic) {
        _coverageGraphic = [AGSGraphic graphicWithGeometry:self.coverage symbol:nil attributes:nil];
    }
    return _coverageGraphic;
}

#pragma mark - Add and remove features
-(void)addItems:(NSArray *)items {
    for (AGSClusterItem *item in items) {
        [self _addItem:item];
    }
}

-(void)removeAllItems {
    [self._int_features removeAllObjects];
    [self._int_clusters removeAllObjects];
    self.isDirty = YES;
    [self recalculateCentroid];
}

#pragma mark - Add and remove features (internal methods for iteration)
-(void)_addItem:(AGSClusterItem *)item {
    if (item.isCluster) {
        AGSCluster *clusterItem = (AGSCluster *)item;
        clusterItem.parentCluster = self;
        [self._int_clusters addObject:item];
        [self._int_features addObjectsFromArray:clusterItem.features];
    } else {
        [self._int_features addObject:item];
    }
    self.isDirty = YES;
}

-(void)_removeItem:(AGSClusterItem *)item {
    if (item.isCluster) {
        AGSCluster *clusterItem = (AGSCluster *)item;
        clusterItem.parentCluster = nil;
        [self._int_clusters removeObject:item];
        [self._int_features removeObjectsInArray:clusterItem.features];
    } else {
        [self._int_features removeObject:item];
    }
    self.isDirty = YES;
}

#pragma mark - Centroid logic
-(void) recalculateCentroid {
    if (!self.isDirty) return;
    
    AGSPoint *centroid = nil;
    NSArray *items = self.features;
    if (items.count == 1) {
        centroid = (AGSPoint *)((AGSClusterItem *)items[0]).geometry;
    } else if (items.count == 0) {
        centroid = [self.parentGrid cellCentroid:self.cellCoordinate];
    } else {
        double xTotal = 0, yTotal = 0;
        AGSSpatialReference *ref = nil;
        for (AGSClusterItem *item in items) {
            AGSPoint *pt = (AGSPoint *)item.geometry;
            xTotal += pt.x;
            yTotal += pt.y;
            if (!ref) ref = pt.spatialReference;
        }
        centroid = [AGSPoint pointWithX:xTotal/items.count y:yTotal/items.count spatialReference:ref];
    }
    self.geometry = centroid;
}

-(void) recalculateCoverage {
    if (!self.isCoverageDirty) return;
    
    if (self.features.count == 1) {
        self.coverage = self.geometry;
    } else if (self.features.count == 2) {
        AGSPoint *pt1 = (AGSPoint *)((AGSClusterItem *)self.features[0]).geometry;
        AGSPoint *pt2 = (AGSPoint *)((AGSClusterItem *)self.features[1]).geometry;
        AGSMutablePolyline *line = [[AGSMutablePolyline alloc] initWithSpatialReference:pt1.spatialReference];
        [line addPathToPolyline];
        [line addPoint:pt1 toPath:0];
        [line addPoint:pt2 toPath:0];
        self.coverage = line;
    } else {
        NSArray *allGeomsForCoverage = [self.features map:^id(id obj) {
            return ((AGSClusterItem *)obj).geometry;
        }];
        AGSGeometry *geom = [[AGSGeometryEngine defaultGeometryEngine] unionGeometries:allGeomsForCoverage];
        AGSGeometry *coverage = [[AGSGeometryEngine defaultGeometryEngine] convexHullForGeometry:geom];
        self.coverage = coverage;
    }
    self.isCoverageDirty = NO;
}

#pragma mark - Description Override
-(NSString *)description {
    return [NSString stringWithFormat:@"Cluster %d (%d features, %d child clusters)", self.clusterId, self._int_features.count, self._int_clusters.count];
}
@end