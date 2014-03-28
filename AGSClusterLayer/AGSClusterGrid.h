//
//  AGSClusterGrid.h
//  ClusterLayerSample
//
//  With much thanks to Leaflet.markercluster's DistanceGrid code:
//  https://github.com/Leaflet/Leaflet.markercluster/blob/master/src/DistanceGrid.js
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@interface AGSClusterGrid : NSObject
@property (nonatomic, strong, readonly) NSArray *clusters;
@property (nonatomic, readonly, assign) NSUInteger cellSize;
-(id)initWithCellSize:(NSUInteger)cellSize;
-(void)addFeature:(id<AGSFeature>)feature;
-(void)addFeatures:(NSArray *)features;
-(void)updateFeature:(id<AGSFeature>)feature;
-(BOOL)removeFeature:(id<AGSFeature>)feature;
-(void)removeAllFeatures;
@end
