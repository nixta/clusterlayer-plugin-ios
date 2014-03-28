//
//  NSArray+Utils.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/28/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "NSArray+Utils.h"

@implementation NSArray (Utils)
- (NSArray *)map: (id (^)(id obj))block
{
    NSMutableArray *new = [NSMutableArray array];
    for(id obj in self)
    {
        id newObj = block(obj);
        [new addObject: newObj ? newObj : [NSNull null]];
    }
    return new;
}
@end


