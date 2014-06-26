//
//  AGSCluster.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@interface AGSCluster : AGSGraphic

//Number of features in the cluster
@property (nonatomic, readonly) NSUInteger featureCount;

//Unique key identifying the cluster item
@property (nonatomic, readonly) id clusterItemKey;

//Direct child clusters of this cluster
@property (nonatomic, readonly) NSArray *childClusters; 

//All features, including (recursively) those of child-clusters
@property (nonatomic, readonly) NSArray *features; 

//Coverage geometry of the cluster
@property (nonatomic, readonly) AGSGeometry *coverage;

//Envelope of the coverage
@property (nonatomic, readonly) AGSEnvelope *envelope;

//The coverage graphic of the cluster
@property (nonatomic, readonly) AGSGraphic *coverageGraphic;

//Initializes and returns an AGSCluster object for the given point
+(AGSCluster *)clusterForPoint:(AGSPoint *)point;

//Adds a list of AGSClusterItem objects on the cluster
-(void)addItems:(NSArray *)items;

//Removes all features and child clusters in the cluster
-(void)removeAllItems;

@end
