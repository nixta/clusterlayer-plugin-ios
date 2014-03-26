//
//  AGSClusterLayerRenderer.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterLayerRenderer.h"
#import <objc/runtime.h>

#define kClusterPayloadKey @"__cluster"

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
                     
                     NSUInteger innerSize = 30;
                     NSUInteger borderSize = 4;
                     AGSSimpleMarkerSymbol *backgroundSymbol1 = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor purpleColor] colorWithAlphaComponent:0.7]];
                     backgroundSymbol1.outline = nil;
                     backgroundSymbol1.size = CGSizeMake(innerSize + borderSize, innerSize + borderSize);
                     AGSSimpleMarkerSymbol *backgroundSymbol2 = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor whiteColor] colorWithAlphaComponent:0.7]];
                     backgroundSymbol2.outline = nil;
                     backgroundSymbol2.size = CGSizeMake(innerSize + (borderSize/2), innerSize + (borderSize/2));
                     AGSSimpleMarkerSymbol *backgroundSymbol3 = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor purpleColor] colorWithAlphaComponent:0.7]];
                     backgroundSymbol3.outline = nil;
                     backgroundSymbol3.size = CGSizeMake(innerSize, innerSize);
                     
                     AGSTextSymbol *countSymbol = [AGSTextSymbol textSymbolWithText:[NSString stringWithFormat:@"%d", cluster.features.count]
                                                                              color:[UIColor whiteColor]];
                     countSymbol.fontSize = 16;
                     [s addSymbol:backgroundSymbol1];
                     [s addSymbol:backgroundSymbol2];
                     [s addSymbol:backgroundSymbol3];
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
    if (cluster) {
        if ([feature.geometry isKindOfClass:[AGSPolygon class]]) {
            // This is a coverage
            return self.coverageGenBlock(cluster);
        }

        return self.clusterGenBlock(cluster);
    } else {
        return [self.originalRenderer symbolForFeature:feature timeExtent:timeExtent];        
    }
    return nil;
}
@end
