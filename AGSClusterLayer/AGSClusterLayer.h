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

@interface AGSClusterLayer : AGSGraphicsLayer
@property (nonatomic, assign) BOOL showClusterCoverages;
@property (nonatomic, assign) NSUInteger minClusterCount;
@property (nonatomic, assign) double minScaleForClustering;
@property (nonatomic, readonly) BOOL willClusterAtCurrentScale;

@property (nonatomic, readonly) AGSEnvelope *clustersEnvelope;

+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer;
+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer
                        usingClusterSymbolBlock:(AGSClusterSymbolGeneratorBlock)clusterBlock
                            coverageSymbolBlock:(AGSClusterSymbolGeneratorBlock)coverageBlock;
@end
