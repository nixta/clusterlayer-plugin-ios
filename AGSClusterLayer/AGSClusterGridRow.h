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
@property (nonatomic, weak) AGSClusterGrid *parentGrid;
@property (nonatomic, strong, readonly) NSMutableDictionary *clusters;

+(AGSClusterGridRow *)clusterGridRowForClusterGrid:(AGSClusterGrid *)parentGrid;

-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord atPoint:(AGSPoint *)point;
-(void)removeAllClusters;
@end

