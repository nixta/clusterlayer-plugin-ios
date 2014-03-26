//
//  AGSCluster.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@interface AGSCluster : NSObject
@property (nonatomic, readonly) AGSPoint *location;
@property (nonatomic, readonly) AGSGeometry *coverage;
@property (nonatomic, readonly) NSArray *features;

+(AGSCluster *)clusterForPoint:(AGSPoint *)point;

-(void)addFeature:(id<AGSFeature>)feature;
-(BOOL)removeFeature:(id<AGSFeature>)feature;
-(void)clearFeatures;
@end
