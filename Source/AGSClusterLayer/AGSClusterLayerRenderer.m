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

@interface AGSClusterLayerRenderer ()
@property (nonatomic, weak) AGSRenderer *originalRenderer;
@end

@implementation AGSClusterLayerRenderer
-(id)initAsSurrogateFor:(AGSRenderer *)originalRenderer {
    self = [self init];
    if (self) {
        self.originalRenderer = originalRenderer;
    }
    return self;
}

-(AGSSymbol *)symbolForFeature:(id<AGSFeature>)feature timeExtent:(AGSTimeExtent *)timeExtent {
    if ([feature.geometry isKindOfClass:[AGSPolygon class]]) {
        // This is a coverage
        return [AGSSimpleFillSymbol simpleFillSymbolWithColor:[[UIColor orangeColor] colorWithAlphaComponent:0.3]
                                                 outlineColor:[[UIColor orangeColor] colorWithAlphaComponent:0.7]];
    }

    AGSCluster *cluster = objc_getAssociatedObject(feature, @"__cluster");
    if (cluster) {
        if (cluster.features.count > 1) {
            // Render a cluster
            AGSCompositeSymbol *s = [AGSCompositeSymbol compositeSymbol];
            AGSSimpleMarkerSymbol *backgroundSymbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor purpleColor] colorWithAlphaComponent:0.7]];
            backgroundSymbol.outline = nil;
            backgroundSymbol.size = CGSizeMake(20, 20);
            AGSTextSymbol *countSymbol = [AGSTextSymbol textSymbolWithText:[NSString stringWithFormat:@"%d", cluster.features.count]
                                                                     color:[UIColor whiteColor]];

            [s addSymbol:backgroundSymbol];
            [s addSymbol:countSymbol];
            
            return s;
        } else if (cluster.features.count == 1) {
            // Render a feature
            return [self.originalRenderer symbolForFeature:feature timeExtent:timeExtent];
        }
    }
    NSLog(@"!!!!!CLUSTER RENDERER CONFUSED!!!!!!!!");
    return nil;
}
@end
