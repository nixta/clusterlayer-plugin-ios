//
//  AGSClusterGridRow.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 4/7/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@class AGSClusterGrid;
@class AGSCluster;

@interface AGSClusterGridRow : NSObject
@property (nonatomic, strong) NSMutableDictionary *rowClusters;
@property (nonatomic, weak) AGSClusterGrid *grid;
@property (nonatomic, readonly) NSArray *clusters;
-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord atPoint:(AGSPoint *)point;
-(void)removeAllClusters;

+(AGSClusterGridRow *)clusterGridRowForClusterGrid:(AGSClusterGrid *)parentGrid;
+(NSUInteger)createdCellCount;
@end

