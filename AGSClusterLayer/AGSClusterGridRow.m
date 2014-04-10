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

@interface AGSClusterGridRow ()
@property (nonatomic, strong) NSMutableDictionary *clusterCells;
@end

@implementation AGSClusterGridRow
+(AGSClusterGridRow *)clusterGridRowForClusterGrid:(AGSClusterGrid *)parentGrid {
    return [[AGSClusterGridRow alloc] initForClusterGrid:parentGrid];
}

-(id)initForClusterGrid:(AGSClusterGrid *)parentGrid {
    self = [super init];
    if (self) {
        self.clusterCells = [NSMutableDictionary dictionary];
        self.grid = parentGrid;
    }
    return self;
}

-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord atPoint:(AGSPoint *)point{
    AGSCluster *result = self.clusterCells[@(gridCoord.x)];
    if (!result) {
        result = [AGSCluster clusterForPoint:point];
        result.cellCoordinate = gridCoord;
        result.parentGrid = self.grid;
        [self.clusterCells setObject:result forKey:@(gridCoord.x)];
    }
    return result;
}

-(NSArray *)clusters {
    return self.clusterCells.allValues;
}

-(void)removeAllClusters {
    [self.clusterCells removeAllObjects];
}
@end
