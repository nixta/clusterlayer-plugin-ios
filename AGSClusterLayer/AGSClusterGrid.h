//
//  AGSClusterGrid.h
//  Cluster Layer
//
//  With much thanks to Leaflet.markercluster's DistanceGrid code:
//  https://github.com/Leaflet/Leaflet.markercluster/blob/master/src/DistanceGrid.js
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@class AGSClusterLayer;

@interface AGSClusterGrid : NSObject
@property (nonatomic, readonly, assign) NSUInteger cellSize;
@property (nonatomic, strong, readonly) NSArray *clusters;

@property (nonatomic, strong) NSNumber *zoomLevel;
@property (nonatomic, strong) AGSClusterGrid *gridForNextZoomLevel;
@property (nonatomic, strong) AGSClusterGrid *gridForPrevZoomLevel;

-(id)initWithCellSize:(NSUInteger)cellSize forClusterLayer:(AGSClusterLayer*)clusterLayer;

-(void)addItems:(NSArray *)items;
-(void)removeAllItems;

-(AGSPoint *)cellCentroid:(CGPoint)cellCoord;
@end
