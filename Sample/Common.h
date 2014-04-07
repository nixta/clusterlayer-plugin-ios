//
//  Common.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/28/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#ifndef ClusterLayerSample_Common_h
#define ClusterLayerSample_Common_h

#define kClusterPayloadKey @"__cluster"

typedef AGSGraphic AGSClusterItem;

@interface AGSGraphic (AGSClusterItem)
-(id)clusterItemKey;
@end
#endif
