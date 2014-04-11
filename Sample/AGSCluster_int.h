//
//  AGSCluster.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>
#import "AGSClusterGrid.h"

@interface AGSCluster (_internal)
@property (nonatomic, assign) CGPoint cellCoordinate;
@property (nonatomic, strong) AGSClusterGrid *parentGrid;
@end
