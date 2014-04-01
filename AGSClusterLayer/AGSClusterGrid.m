//
//  AGSClusterDistanceGrid.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterGrid.h"
#import "AGSCluster.h"
#import "AGSCluster_int.h"
#import <objc/runtime.h>

#define kAddFeaturesArrayKey @"__tempArrayKey"

typedef AGSGraphic AGSClusterItem;

#pragma mark - Helper Methods
CGPoint getGridCoordForMapPoint(AGSPoint* pt, NSUInteger cellSize) {
    return CGPointMake(floor(pt.x/cellSize), floor(pt.y/cellSize));
}

AGSPoint* getGridCellCentroid(CGPoint cellCoord, NSUInteger cellSize) {
    return [AGSPoint pointWithX:(cellCoord.x * cellSize) + (cellSize/2)
                              y:cellCoord.y * cellSize + (cellSize/2)
               spatialReference:[AGSSpatialReference webMercatorSpatialReference]];
}


#pragma mark - Internal Helper Classes
@interface AGSClusterGridRow : NSObject
@property (nonatomic, strong) NSMutableDictionary *rowClusters;
@property (nonatomic, weak) AGSClusterGrid *grid;
-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord;
@end

@implementation AGSClusterGridRow
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
        // Create a new cluster if necessary
        result = [AGSCluster clusterForPoint:getGridCellCentroid(gridCoord, self.grid.cellSize)];
        result.cellCoordinate = gridCoord;
        [self.rowClusters setObject:result forKey:@(gridCoord.x)];
    }
    return result;
}
@end


#pragma mark - Cluster Grid
@interface AGSClusterGrid()
@property (nonatomic, assign, readwrite) NSUInteger cellSize;
@property (nonatomic, strong) NSMutableDictionary* grid;
@property (nonatomic, strong, readwrite) NSMutableSet *items;
//-(void)rebuildClusters;
@end

@implementation AGSClusterGrid
-(id)initWithCellSize:(NSUInteger)cellSize {
    self = [self init];
    if (self) {
        self.cellSize = cellSize;
        self.grid = [NSMutableDictionary dictionary];
        self.items = [NSMutableSet set];
    }
    return self;
}

//-(void)addItem:(AGSClusterItem *)item {
//    // Get the cluster we need to add the graphic to
//    AGSCluster *cluster = [self getClusterForItem:item];
//    // Add the graphic (it could be a cluster or a feature)
//    [cluster addFeature:item];
//
//    [[self gridForPrevZoomLevel] addItem:cluster];
//}

-(void)replaceItems:(NSArray *)items {
    for (id<AGSFeature>f in items) {
        if (![f isKindOfClass:[AGSCluster class]]) {
            NSLog(@"Feature %d", f.featureId);
        }
    }
    [self removeAllItems];
    self.items = [NSMutableSet setWithArray:items];
    [self clusterItems];
    [self.gridForPrevZoomLevel replaceItems:self.clusters];
}

-(void)addItems:(NSArray *)items {
    [self.items addObjectsFromArray:items];
    [self clusterItems];
    [self.gridForPrevZoomLevel replaceItems:self.clusters];
}

-(void)clusterItems {
    NSSet *items = self.items;
    NSLog(@"Adding %d features/clusters to zoom level %@", items.count, self.zoomLevel);

    // Add each item to the clusters (creating new ones if necessary).
    NSMutableSet *clustersForItems = [NSMutableSet set];
    for (AGSClusterItem *item in items) {
        // Find out what cluster this item should belong to.
        AGSCluster *cluster = [self getClusterForItem:item];
        
        // And track this item in an array associated with this cluster.
        NSMutableArray *itemsToAddToCluster = objc_getAssociatedObject(cluster, kAddFeaturesArrayKey);
        if (!itemsToAddToCluster) {
            itemsToAddToCluster = [NSMutableArray array];
            objc_setAssociatedObject(cluster, kAddFeaturesArrayKey, itemsToAddToCluster, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [itemsToAddToCluster addObject:item];
        
        // Also track the clusters we've touched with these items.
        [clustersForItems addObject:cluster];
    }
    
    // Now go over the clusters we've touched
    // And bulk add items to each individual cluster.
    for (AGSCluster *cluster in clustersForItems) {
        NSArray *itemsToAdd = objc_getAssociatedObject(cluster, kAddFeaturesArrayKey);
        [cluster addItems:itemsToAdd];
        // Remove the temporary reference to the array that tracked the items to add to this cluster
        objc_setAssociatedObject(cluster, kAddFeaturesArrayKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
}

//-(void)rebuildClusters {
//    // Rebuild our clusters based off the next zoom level's clusters.
//    if (self.gridForNextZoomLevel) {
//        [self removeAllItems];
//        [self addItems:self.gridForNextZoomLevel.clusters];
//    }
//}

//-(BOOL)removeItem:(AGSClusterItem *)item {
//    [self.gridForPrevZoomLevel removeItem:item];
//    
//    AGSCluster *cluster = [self getClusterForItem:item];
//    BOOL result = [cluster removeFeature:item];
//    if (cluster.features.count == 0) {
//        CGPoint cellCoord = cluster.cellCoordinate;
//        NSMutableDictionary *row = self.grid[@(cellCoord.y)];
//        [row removeObjectForKey:@(cellCoord.x)];
//    }
//    return result;
//}

-(void)removeAllItems {
    for (AGSClusterGridRow *row in self.grid.allValues) {
        for (AGSCluster *cluster in row.rowClusters.allValues) {
            [cluster clearItems];
        }
        [row.rowClusters removeAllObjects];
    }
    [self.grid removeAllObjects];
//    NSLog(@"Removed items for zoom level %@", self.zoomLevel);
}

-(AGSCluster *)getClusterForItem:(AGSGraphic *)graphic {
    AGSPoint *pt = (AGSPoint *)graphic.geometry;
    NSAssert(pt != nil, @"Graphic Geometry is NIL!");
    
    // What cell (cluster) should this graphic go into?
    CGPoint gridCoord = getGridCoordForMapPoint(pt, self.cellSize);
    
    // Return the cluster
    return [self clusterForGridCoord:gridCoord];
}

-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord {
    // Find the cells along that row.
    AGSClusterGridRow *row = [self rowForGridCoord:gridCoord];
    
    // Find the cluster within that row
    return [row clusterForGridCoord:gridCoord];
}

-(AGSClusterGridRow *)rowForGridCoord:(CGPoint)gridCoord {
    AGSClusterGridRow *row = self.grid[@(gridCoord.y)];
    if (!row) {
        row = [[AGSClusterGridRow alloc] initForClusterGrid:self];
        [self.grid setObject:row forKey:@(gridCoord.y)];
    }
    return row;
}

-(NSArray *)clusters {
    NSMutableArray *clusters = [NSMutableArray array];
    for (AGSClusterGridRow *row in self.grid.allValues) {
        for (AGSCluster *cluster in row.rowClusters.allValues) {
            [clusters addObject:cluster];
        }
    }
    return [NSArray arrayWithArray:clusters];
}

//-(AGSGraphic *)getItemNear:(AGSPoint *)mapPoint {
//    double closestDistance = (double)self.cellSize;
//    id closestItem = nil;
//    for (AGSCluster *cluster in self.clusters) {
//        for (AGSGraphic *item in cluster.features) {
//            double distance = [[AGSGeometryEngine defaultGeometryEngine] distanceFromGeometry:item.geometry toGeometry:mapPoint];
//            if (distance < closestDistance) {
//                closestItem = item;
//                closestDistance = distance;
//            }
//        }
//    }
//    return closestItem;
//}

-(NSString *)description {
    NSUInteger clusterCount = 0;
    NSUInteger featureCount = 0;
    NSUInteger loneFeatures = 0;
    for (AGSCluster *cluster in self.clusters) {
        if (cluster.features.count > 1) {
            clusterCount++;
        } else {
            loneFeatures++;
        }
        featureCount += cluster.features.count;
    }
    return [NSString stringWithFormat:@"Cluster Layer: %d features in %d clusters (with %d unclustered)", featureCount, clusterCount, loneFeatures];
}
@end
