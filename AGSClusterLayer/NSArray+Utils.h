//
//  NSArray+Utils.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/28/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (Utils)
- (NSArray *)map: (id (^)(id obj))block;
@end
