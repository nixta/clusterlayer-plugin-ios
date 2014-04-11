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
@property (nonatomic, assign, readonly) NSUInteger cellSize;
-(id)initWithCellSize:(NSUInteger)cellSize forClusterLayer:(AGSClusterLayer *)clusterLayer;
-(AGSPoint *)cellCentroid:(CGPoint)cellCoord;
@end
