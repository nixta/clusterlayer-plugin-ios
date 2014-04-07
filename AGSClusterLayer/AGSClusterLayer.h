//
//  AGSClusterLayer.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ArcGIS/ArcGIS.h>
#import "AGSClusterLayerRenderer.h"

extern NSString * const AGSClusterLayerDidCompleteClusteringNotification;
extern NSString * const AGSClusterLayerDidCompleteClusteringNotificationUserInfo_Duration;
extern NSString * const AGSClusterLayerDidCompleteClusteringNotificationUserInfo_ClusterCount;
extern NSString * const AGSClusterLayerDidCompleteClusteringNotificationUserInfo_FeatureCount;
extern NSString * const AGSClusterLayerDidCompleteClusteringNotificationUserInfo_ClusteringCellsize;

extern NSString * const AGSClusterLayerLoadFeaturesProgressNotification;
extern NSString * const AGSClusterLayerLoadFeaturesProgressNotification_UserInfo_PercentComplete;
extern NSString * const AGSClusterLayerLoadFeaturesProgressNotification_UserInfo_TotalRecordsToLoad;
extern NSString * const AGSClusterLayerLoadFeaturesProgressNotification_UserInfo_RecordsLoaded;

@interface AGSClusterLayer : AGSGraphicsLayer

@property (nonatomic, assign) BOOL showClusterCoverages;
@property (nonatomic, assign) NSUInteger minClusterCount;
@property (nonatomic, assign) double minScaleForClustering;
@property (nonatomic, readonly) BOOL willClusterAtCurrentScale;

-(AGSEnvelope *)clustersEnvelopeForZoomLevel:(NSUInteger)zoomLevel;

+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer;
+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer
                        usingClusterSymbolBlock:(AGSClusterSymbolGeneratorBlock)clusterBlock
                            coverageSymbolBlock:(AGSClusterSymbolGeneratorBlock)coverageBlock;
@end
