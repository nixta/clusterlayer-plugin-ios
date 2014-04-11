//
//  AGSCL.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 4/10/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSCluster.h"
#import "AGSClusterLayerRenderer.h"
#import "AGSClusterLayer.h"

#ifndef ClusterLayerSample_AGSCL_h
#define ClusterLayerSample_AGSCL_h

#pragma mark - Notifications
extern NSString * const AGSClusterLayerLoadFeaturesProgressNotification;
extern NSString * const AGSClusterLayerLoadFeaturesProgressNotification_UserInfo_PercentComplete;
extern NSString * const AGSClusterLayerLoadFeaturesProgressNotification_UserInfo_TotalRecordsToLoad;
extern NSString * const AGSClusterLayerLoadFeaturesProgressNotification_UserInfo_RecordsLoaded;

extern NSString * const AGSClusterLayerClusteringProgressNotification;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_PercentComplete;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_TotalZoomLevels;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_CompletedZoomLevels;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_FeatureCount;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_Duration;

extern NSString * const AGSClusterGridClusteringNotification;
extern NSString * const AGSClusterGridClusteredNotification;

#endif
