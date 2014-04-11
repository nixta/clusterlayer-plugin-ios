//
//  AGSClusterLayer.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import "AGSClusterLayerRenderer.h"

@interface AGSClusterLayer : AGSGraphicsLayer
@property (nonatomic, assign) NSUInteger minClusterCount;
@property (nonatomic, assign) double minScaleForClustering;
@property (nonatomic, readonly) BOOL willClusterAtCurrentScale;
@property (nonatomic, assign) BOOL showClusterCoverages;

-(AGSEnvelope *)clustersEnvelopeForZoomLevel:(NSUInteger)zoomLevel;

+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer;
+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer
                        usingClusterSymbolBlock:(AGSClusterSymbolGeneratorBlock)clusterBlock
                            coverageSymbolBlock:(AGSClusterSymbolGeneratorBlock)coverageBlock;
@end
