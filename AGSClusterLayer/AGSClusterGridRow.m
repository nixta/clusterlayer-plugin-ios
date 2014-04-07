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

AGSPoint* getGridCellCentroid(CGPoint cellCoord, NSUInteger cellSize) {
    return [AGSPoint pointWithX:(cellCoord.x * cellSize) + (cellSize/2)
                              y:cellCoord.y * cellSize + (cellSize/2)
               spatialReference:[AGSSpatialReference webMercatorSpatialReference]];
}

@implementation AGSClusterGridRow
+(AGSClusterGridRow *)clusterGridRowForClusterGrid:(AGSClusterGrid *)parentGrid {
    return [[AGSClusterGridRow alloc] initForClusterGrid:parentGrid];
}

-(id)initForClusterGrid:(AGSClusterGrid *)parentGrid {
    self = [super init];
    if (self) {
        self.rowClusters = [NSMutableDictionary dictionary];
        self.grid = parentGrid;
    }
    return self;
}

-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord {
    AGSCluster *result = self.rowClusters[@(gridCoord.x)];
    if (!result) {
        result = [AGSCluster clusterForPoint:getGridCellCentroid(gridCoord, self.grid.cellSize)];
        result.cellCoordinate = gridCoord;
        [self.rowClusters setObject:result forKey:@(gridCoord.x)];
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
