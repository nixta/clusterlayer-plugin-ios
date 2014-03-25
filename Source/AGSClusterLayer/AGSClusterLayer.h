//
//  AGSClusterLayer.h
//  AGSCluseterLayer
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ArcGIS/ArcGIS.h>

@interface AGSClusterLayer : AGSGraphicsLayer
@property (nonatomic, assign) BOOL showClusterCoverages;
+(AGSClusterLayer *)clusterLayerWithURL:(NSURL *)featureLayerURL;
+(AGSClusterLayer *)clusterLayerWithURL:(NSURL *)featureLayerURL credential:(AGSCredential *)cred;
-(id)initWithURL:(NSURL *)featureLayerURL;
-(id)initWithURL:(NSURL *)featureLayerURL credential:(AGSCredential *)cred;
@end
