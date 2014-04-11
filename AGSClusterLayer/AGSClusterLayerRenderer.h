//
//  AGSClusterLayerRenderer.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>

@class AGSCluster;

// A block with this signature will be passed a cluster and is expected to return an AGSSymbol.
typedef AGSSymbol*(^AGSClusterSymbolGeneratorBlock)(AGSCluster *);

@interface AGSClusterLayerRenderer : AGSSimpleRenderer
-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer;
-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer
     clusterSymbolBlock:(AGSClusterSymbolGeneratorBlock)clusterSymbolGenerator   // Symbol for the cluster point
    coverageSymbolBlock:(AGSClusterSymbolGeneratorBlock)coverageSymbolGenerator; // Symbol for the cluster coverage
@end