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
@property (nonatomic, readonly) NSUInteger displayCount;
@property (nonatomic, readonly) id clusterItemKey;

@property (nonatomic, readonly) NSArray *childClusters; // Direct child clusters of this cluster
@property (nonatomic, readonly) NSArray *features; // All features, including (recursively) those of child-clusters

@property (nonatomic, readonly) AGSGeometry *coverage;
@property (nonatomic, readonly) AGSEnvelope *envelope;
@property (nonatomic, readonly) AGSGraphic *coverageGraphic;

+(AGSCluster *)clusterForPoint:(AGSPoint *)point;

-(void)addItems:(NSArray *)items;
-(void)removeAllItems;
@end
