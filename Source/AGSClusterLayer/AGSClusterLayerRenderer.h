//
//  AGSClusterLayerRenderer.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import "AGSCluster.h"

typedef AGSSymbol*(^SymbolGeneratorBlock)(AGSCluster *);

@interface AGSClusterLayerRenderer : AGSSimpleRenderer
-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer;
-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer clusterSymbolBlock:(SymbolGeneratorBlock)clusterSymbolGenerator coverageSymbolBlock:(SymbolGeneratorBlock)coverageSymbolGenerator;
@end