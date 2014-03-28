//
//  AGSCluster.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@interface AGSGraphic (AGSClustering)
@property (nonatomic, readonly) BOOL isCluster;
@end

@interface AGSCluster : AGSGraphic <AGSFeature>
@property (nonatomic, readonly) AGSGeometry *coverage;
@property (nonatomic, readonly) NSArray *features;
@property (nonatomic, readonly) NSArray *clusters;

+(AGSCluster *)clusterForPoint:(AGSPoint *)point;

-(void)addFeature:(id<AGSFeature>)feature;
-(void)addFeatures:(NSArray *)features;
-(BOOL)removeFeature:(id<AGSFeature>)feature;
-(void)clearFeatures;
@end
