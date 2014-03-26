//
//  AGSClusterLayerRenderer.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
@class AGSClusterLayer;

@interface AGSClusterLayerRenderer : AGSSimpleRenderer
-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer;
@end