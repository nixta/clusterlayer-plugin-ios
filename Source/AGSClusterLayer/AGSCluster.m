//
//  AGSCluster.m
//  AGSCluseterLayer
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSCluster.h"

@interface AGSCluster ()
@property (nonatomic, strong) AGSPoint *gridCentroid;
@property (nonatomic, strong) AGSPoint *calculatedCentroid;
@property (nonatomic, strong) AGSGeometry *calculatedCoverage;
@property (nonatomic, strong) NSMutableArray *_rawFeatures;
@end

@implementation AGSCluster
+(AGSCluster *)clusterForPoint:(AGSPoint *)point {
    return [[AGSCluster alloc] initWithPoint:point];
}

-(id)initWithPoint:(AGSPoint *)point {
    self = [self init];
    if (self) {
        self.gridCentroid = point;
        self.calculatedCentroid = point;
        self.calculatedCoverage = point;
        self._rawFeatures = [NSMutableArray array];
    }
    return self;
}

-(NSArray *)features {
    return [NSArray arrayWithArray:self._rawFeatures];
}

-(void)addFeature:(id<AGSFeature>)feature {
    [self._rawFeatures addObject:feature];
    [self recalculateCentroid];
}

-(void) recalculateCentroid {
    AGSMutableMultipoint *mp = nil;
    for (id<AGSFeature> f in self.features) {
        if (!mp) {
            mp = [[AGSMutableMultipoint alloc] initWithSpatialReference:f.geometry.spatialReference];
        }
        [mp addPoint:(AGSPoint *)f.geometry];
    }
    switch (mp.numPoints) {
        case 0:
        case 1:
        {
            self.calculatedCoverage = self.gridCentroid;
            self.calculatedCentroid = self.gridCentroid;
            break;
        }
        case 2:
        {
            AGSPolyline *cl = (AGSPolyline *)[[AGSGeometryEngine defaultGeometryEngine] convexHullForGeometry:mp];
            AGSPoint *pt1 = [cl pointOnPath:0 atIndex:0];
            AGSPoint *pt2 = [cl pointOnPath:0 atIndex:1];
            AGSMutablePolygon *p = [[AGSMutablePolygon alloc] initWithSpatialReference:cl.spatialReference];
            [p addRingToPolygon];
            [p addPointToRing:pt1];
            [p addPointToRing:pt2];
            [p closePolygon];
            self.calculatedCoverage = p;
            self.calculatedCentroid = [AGSPoint pointWithX:(pt1.x+pt2.x)/2
                                                         y:(pt1.y+pt2.y)/2
                                          spatialReference:cl.spatialReference];
            break;
        }
        default:
        {
            self.calculatedCoverage = (AGSPolygon *)[[AGSGeometryEngine defaultGeometryEngine] convexHullForGeometry:mp];
            self.calculatedCentroid = [[AGSGeometryEngine defaultGeometryEngine] labelPointForPolygon:(AGSPolygon *)self.calculatedCoverage];
            break;
        }
    }
}

-(AGSPoint *)location {
    return self.calculatedCentroid;
}

-(AGSGeometry *)coverage {
    return self.calculatedCoverage;
}

-(BOOL)removeFeature:(id<AGSFeature>)feature {
    if ([self._rawFeatures containsObject:feature]) {
        [self._rawFeatures removeObject:feature];
        return YES;
    }
    return NO;
}

-(void)clearFeatures {
    [self._rawFeatures removeAllObjects];
}
@end