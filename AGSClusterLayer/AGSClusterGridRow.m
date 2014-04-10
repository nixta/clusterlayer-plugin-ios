//
//  AGSClusterGridRow.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 4/7/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterGridRow.h"
#import "AGSCluster.h"
#import "AGSCluster_int.h"
#import "AGSClusterGrid.h"

@implementation AGSClusterGridRow
+(AGSClusterGridRow *)clusterGridRowForClusterGrid:(AGSClusterGrid *)parentGrid {
    return [[AGSClusterGridRow alloc] initForClusterGrid:parentGrid];
}

+(NSUInteger)createdCellCount {
    static NSUInteger count = 0;
    return count++;
}

-(id)initForClusterGrid:(AGSClusterGrid *)parentGrid {
    self = [super init];
    if (self) {
        self.rowClusters = [NSMutableDictionary dictionary];
        self.grid = parentGrid;
    }
    return self;
}

-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord atPoint:(AGSPoint *)point{
    AGSCluster *result = self.rowClusters[@(gridCoord.x)];
    if (!result) {
        result = [AGSCluster clusterForPoint:point];
        result.cellCoordinate = gridCoord;
        [self.rowClusters setObject:result forKey:@(gridCoord.x)];
        [AGSClusterGridRow createdCellCount];
    }
    return result;
}

-(NSArray *)clusters {
    return self.rowClusters.allValues;
}

-(void)removeAllClusters {
    [self.rowClusters removeAllObjects];
}
@end
