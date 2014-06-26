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

//The minimum number of features required to render as a cluster.
@property (nonatomic, assign) NSUInteger minClusterCount; 

// The minimum scale beyond which clustering is not rendered.
@property (nonatomic, assign) double minScaleForClustering; 

//The boolean value indicating whether clustering can be performed at the current scale
@property (nonatomic, readonly) BOOL willClusterAtCurrentScale;

//The boolean value to toggle cluster coverage visibility
@property (nonatomic, assign) BOOL showsClusterCoverages;

//Returns an envelope which is the union of all cluster-coverage envelopes in the provided zoom level
-(AGSEnvelope *)envelopeForClustersAtZoomLevel:(NSUInteger)zoomLevel;

//Initializes and returns a cluster layer for the provided feature layer
+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer;

//Initializes and returns a cluster layer for the provided feature layer, cluster symbol block and coverage symbol block
+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer
                        usingClusterSymbolBlock:(AGSClusterSymbolGeneratorBlock)clusterBlock
                            coverageSymbolBlock:(AGSClusterSymbolGeneratorBlock)coverageBlock;
@end
