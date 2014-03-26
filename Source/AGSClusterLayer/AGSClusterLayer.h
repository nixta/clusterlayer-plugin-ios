//
//  AGSClusterLayer.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ArcGIS/ArcGIS.h>

@interface AGSClusterLayer : AGSGraphicsLayer
@property (nonatomic, assign) BOOL showClusterCoverages;
+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer;
@end
