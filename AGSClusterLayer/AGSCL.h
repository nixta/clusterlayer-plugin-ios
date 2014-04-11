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
extern NSString * const AGSClusterLayerDataLoadingProgressNotification;
extern NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_PercentComplete;
extern NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_TotalRecordsToLoad;
extern NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_RecordsLoaded;

extern NSString * const AGSClusterLayerDataLoadingErrorNotification;
extern NSString * const AGSClusterLayerDataLoadingErrorNotification_UserInfo_Error;

extern NSString * const AGSClusterLayerClusteringProgressNotification;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_PercentComplete;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_TotalZoomLevels;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_CompletedZoomLevels;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_FeatureCount;
extern NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_Duration;

// AGSClusterGridClusteredNotification is abstracted by the above AGSClusterLayerClusteringProgressNotification
// It can be listened to, but exposes internal workings that are subject to change. Use at your own risk.
extern NSString * const AGSClusterGridClusteringNotification;
extern NSString * const AGSClusterGridClusteredNotification;

#pragma mark - Protocols
@protocol AGSClusterGridProvider <NSObject>
@required
@property (nonatomic, strong, readonly) NSArray *clusters;
-(void)addItems:(NSArray *)items;
-(void)removeAllItems;
@end

@protocol AGSZoomLevelClusterGridProvider <AGSClusterGridProvider>
@required
@property (nonatomic, strong) NSNumber *zoomLevel;
@property (nonatomic, strong) id<AGSZoomLevelClusterGridProvider> gridForNextZoomLevel;
@property (nonatomic, strong) id<AGSZoomLevelClusterGridProvider> gridForPrevZoomLevel;
@end

#endif
