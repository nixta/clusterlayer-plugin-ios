//
//  AGSClusterLayerRenderer.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterLayerRenderer.h"
#import <objc/runtime.h>
#import "AGSCluster.h"

#define kClusterPayloadKey @"__cluster"

typedef AGSSymbol*(^SymbolGeneratorBlock)(AGSCluster *);

@interface AGSClusterLayerRenderer ()
@property (nonatomic, weak) AGSRenderer *originalRenderer;
@property (nonatomic, copy) SymbolGeneratorBlock clusterGenBlock;
@property (nonatomic, copy) SymbolGeneratorBlock coverageGenBlock;
@end

@implementation AGSClusterLayerRenderer
-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer {
    self = [self initAsSurrogateFor:originalRenderer
                 clusterSymbolBlock:^(AGSCluster *cluster) {
                     AGSCompositeSymbol *s = [AGSCompositeSymbol compositeSymbol];
                     
                     AGSSimpleMarkerSymbol *backgroundSymbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor purpleColor] colorWithAlphaComponent:0.7]];
                     backgroundSymbol.outline = nil;
                     backgroundSymbol.size = CGSizeMake(20, 20);
                     
                     AGSTextSymbol *countSymbol = [AGSTextSymbol textSymbolWithText:[NSString stringWithFormat:@"%d", cluster.features.count]
                                                                              color:[UIColor whiteColor]];
                     
                     [s addSymbol:backgroundSymbol];
                     [s addSymbol:countSymbol];
                     
                     return s;
                 }
                coverageSymbolBlock:^(AGSCluster *cluster) {
                    return [AGSSimpleFillSymbol simpleFillSymbolWithColor:[[UIColor orangeColor] colorWithAlphaComponent:0.3]
                                                             outlineColor:[[UIColor orangeColor] colorWithAlphaComponent:0.7]];
                }];
    if (self) {
        self.originalRenderer = originalRenderer;
    }
    return self;
}

-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer clusterSymbolBlock:(SymbolGeneratorBlock)clusterSymbolGenerator coverageSymbolBlock:(SymbolGeneratorBlock)coverageSymbolGenerator {
    self = [self init];
    if (self) {
        self.clusterGenBlock = clusterSymbolGenerator;
        self.coverageGenBlock = coverageSymbolGenerator;
    }
    return self;
}

-(AGSSymbol *)symbolForFeature:(id<AGSFeature>)feature timeExtent:(AGSTimeExtent *)timeExtent {
    AGSCluster *cluster = objc_getAssociatedObject(feature, kClusterPayloadKey);

    if ([feature.geometry isKindOfClass:[AGSPolygon class]]) {
        // This is a coverage
        return self.coverageGenBlock(cluster);
    }

    if (cluster) {
        if (cluster.features.count > 1) {
            return self.clusterGenBlock(cluster);
        } else if (cluster.features.count == 1) {
            // Render a feature
            return [self.originalRenderer symbolForFeature:feature timeExtent:timeExtent];
        }
    }
    NSLog(@"!!!!!CLUSTER RENDERER FOUND NON-CLUSTER GRAPHIC!!!!!!!!");
    return nil;
}
@end
