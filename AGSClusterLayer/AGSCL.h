//
//  AGSCL.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 4/10/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterLayer.h"
#import "AGSClusterLayerRenderer.h"
#import "AGSCluster.h"

#ifndef ClusterLayerSample_AGSCL_h
#define ClusterLayerSample_AGSCL_h

#pragma mark - Notifications

// AGSClusterLayerDataLoadingProgressNotification is posted periodically during data load.
extern NSString * const AGSClusterLayerDataLoadingProgressNotification;
extern NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_PercentComplete;
extern NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_TotalRecordsToLoad;
extern NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_RecordsLoaded;

// AGSClusterLayerDataLoadingErrorNotification is posted if data fails to load. UserInfo contains an NSError object.
extern NSString * const AGSClusterLayerDataLoadingErrorNotification;
extern NSString * const AGSClusterLayerDataLoadingErrorNotification_UserInfo_Error;

// AGSClusterLayerClusteringProgressNotification is posted each time a zoom level has clustered. When all zoom levels
// have been clustered, the percentage will be 100.
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
