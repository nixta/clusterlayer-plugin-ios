//
//  AGSClusterLayerRenderer.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/25/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterLayerRenderer.h"
#import <objc/runtime.h>

#import "Common.h"

@interface AGSClusterLayerRenderer ()
@property (nonatomic, weak) AGSRenderer *originalRenderer;
@property (nonatomic, copy) AGSClusterSymbolGeneratorBlock clusterGenBlock;
@property (nonatomic, copy) AGSClusterSymbolGeneratorBlock coverageGenBlock;
@end

@implementation AGSClusterLayerRenderer
-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer {
    self = [self init];
    if (self) {
        self.originalRenderer = originalRenderer;
    }
    return self;
}

-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer
     clusterSymbolBlock:(AGSClusterSymbolGeneratorBlock)clusterSymbolGenerator
    coverageSymbolBlock:(AGSClusterSymbolGeneratorBlock)coverageSymbolGenerator
{
    self = [self initAsSurrogateFor:originalRenderer];
    if (self) {
        if (clusterSymbolGenerator) {
            self.clusterGenBlock = clusterSymbolGenerator;
        }
        if (coverageSymbolGenerator) {
            self.coverageGenBlock = coverageSymbolGenerator;
        }
    }
    return self;
}

-(id)init {
    self = [super init];
    if (self) {
        self.clusterGenBlock = ^(AGSCluster *cluster) {
            AGSCompositeSymbol *s = [AGSCompositeSymbol compositeSymbol];

            NSUInteger innerSize = 24;
            NSUInteger borderSize = 6;
            NSUInteger fontSize = 14;
            
            UIColor *smallClusterColor = [UIColor colorWithRed:0.000 green:0.491 blue:0.000 alpha:1.000];
            UIColor *mediumClusterColor = [UIColor colorWithRed:0.838 green:0.500 blue:0.000 alpha:1.000];
            UIColor *largeClusterColor = [UIColor colorWithRed:0.615 green:0.178 blue:0.550 alpha:1.000];
            UIColor *c = cluster.displayCount < 10?smallClusterColor:(cluster.displayCount < 100?mediumClusterColor:largeClusterColor);
            
            AGSSimpleMarkerSymbol *backgroundSymbol1 = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[c colorWithAlphaComponent:0.7]];
            backgroundSymbol1.outline = nil;
            backgroundSymbol1.size = CGSizeMake(innerSize + borderSize, innerSize + borderSize);
            
            AGSSimpleMarkerSymbol *backgroundSymbol2 = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor whiteColor] colorWithAlphaComponent:0.7]];
            backgroundSymbol2.outline = nil;
            backgroundSymbol2.size = CGSizeMake(innerSize + (borderSize/2), innerSize + (borderSize/2));
            
            AGSSimpleMarkerSymbol *backgroundSymbol3 = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[c colorWithAlphaComponent:0.7]];
            backgroundSymbol3.outline = nil;
            backgroundSymbol3.size = CGSizeMake(innerSize, innerSize);
            
            if (cluster.displayCount > 99) fontSize = fontSize * 0.8;
            AGSTextSymbol *countSymbol = [AGSTextSymbol textSymbolWithText:[NSString stringWithFormat:@"%d", cluster.displayCount]
                                                                     color:[UIColor whiteColor]];
            countSymbol.fontSize = fontSize;
            [s addSymbol:backgroundSymbol1];
            [s addSymbol:backgroundSymbol2];
            [s addSymbol:backgroundSymbol3];
            [s addSymbol:countSymbol];
            
            return s;
        };
        self.coverageGenBlock = ^(AGSCluster *cluster) {
            return [AGSSimpleFillSymbol simpleFillSymbolWithColor:[[UIColor orangeColor] colorWithAlphaComponent:0.3]
                                                     outlineColor:[[UIColor orangeColor] colorWithAlphaComponent:0.7]];
        };
    }
    return self;
}

-(AGSSymbol *)symbolForFeature:(id<AGSFeature>)feature timeExtent:(AGSTimeExtent *)timeExtent {
    if ([feature isKindOfClass:[AGSCluster class]]) {
        return self.clusterGenBlock((AGSCluster *)feature);
    }
    
    AGSCluster *cluster = objc_getAssociatedObject(feature, kClusterPayloadKey);
    if (cluster != nil &&
        [feature.geometry isKindOfClass:[AGSPolygon class]]) {
        // This is a coverage
        return self.coverageGenBlock((AGSCluster *)feature);
    }
        
    return [self.originalRenderer symbolForFeature:feature timeExtent:timeExtent];
}
@end
