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
#import "AGSClusterLayer.h"

@interface AGSClusterGrid : NSObject
@property (nonatomic, strong, readonly) NSArray *clusters;
@property (nonatomic, readonly, assign) NSUInteger cellSize;

@property (nonatomic, strong) NSNumber *zoomLevel;
@property (nonatomic, strong) AGSClusterGrid *gridForNextZoomLevel;
@property (nonatomic, strong) AGSClusterGrid *gridForPrevZoomLevel;

-(id)initWithCellSize:(NSUInteger)cellSize forClusterLayer:(AGSClusterLayer*)clusterLayer;

-(void)addKeyedItems:(NSDictionary *)items;
-(void)removeAllItems;
@end
