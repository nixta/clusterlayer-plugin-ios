//
//  AGSClusterGridRow.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 4/7/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@class AGSClusterGrid;
@class AGSCluster;

@interface AGSClusterGridRow : NSObject

//The cluster grid to which this row belongs to
@property (nonatomic, weak) AGSClusterGrid *parentGrid;

//Clusters in this grid row
@property (nonatomic, strong, readonly) NSMutableDictionary *clusters;

//Initializes and returns an AGSClusterGridRow object for the given cluster grid
+(AGSClusterGridRow *)clusterGridRowForClusterGrid:(AGSClusterGrid *)grid;

//Returns an AGSCluster object for the given grid co-ordinates and point
-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord atPoint:(AGSPoint *)point;
-(void)removeAllClusters;
@end

