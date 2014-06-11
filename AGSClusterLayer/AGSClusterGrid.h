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
#import "AGSCL.h"

@interface AGSClusterGrid : NSObject <AGSZoomLevelClusterGridProvider>

//The cell size of this cluster grid
@property (nonatomic, assign, readonly) NSUInteger cellSize;

//Initializes an AGSClusterGrid object for the cluster layer with the given cell size
-(id)initWithCellSize:(NSUInteger)cellSize forClusterLayer:(AGSClusterLayer *)clusterLayer;

//Returns the centroid for the given cell co-ordinate 
-(AGSPoint *)cellCentroid:(CGPoint)cellCoord;
@end
