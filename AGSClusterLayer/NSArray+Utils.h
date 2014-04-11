//
//  NSArray+Utils.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/28/14.
//  With thanks to https://mikeash.com/pyblog/friday-qa-2009-08-14-practical-blocks.html

#import <Foundation/Foundation.h>

@interface NSArray (Utils)
- (NSArray *)map: (id (^)(id obj))block;
@end
