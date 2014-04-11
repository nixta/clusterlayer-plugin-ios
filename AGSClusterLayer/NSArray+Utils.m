//
//  NSArray+Utils.m
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/28/14.
//  With thanks to https://mikeash.com/pyblog/friday-qa-2009-08-14-practical-blocks.html

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


