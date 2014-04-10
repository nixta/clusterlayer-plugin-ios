//
//  AGSCluster.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@interface AGSCluster : AGSGraphic

@property (nonatomic, readonly) id clusterItemKey;

@property (nonatomic, readonly) NSArray *items;
@property (nonatomic, readonly) NSArray *features;
@property (nonatomic, readonly) NSArray *clusters;

@property (nonatomic, readonly) NSUInteger displayCount;

@property (nonatomic, readonly) AGSGeometry *coverage;
@property (nonatomic, readonly) AGSGraphic *coverageGraphic;

+(AGSCluster *)clusterForPoint:(AGSPoint *)point;

-(void)addItem:(AGSGraphic *)item;
-(void)addItems:(NSArray *)items;
-(void)removeItem:(AGSGraphic *)item;
-(void)clearItems;
@end
