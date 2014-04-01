//
//  AGSGraphic+AGSClustering.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/28/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSGraphic+AGSClustering.h"
#import <objc/runtime.h>
#import "AGSCluster.h"

@implementation AGSGraphic (AGSClustering)
-(BOOL)isCluster {
    return [self isKindOfClass:[AGSCluster class]];
}

-(BOOL)isClusterCoverage {
    return NO;
}
@end
