//
//  AGSGraphic+AGSClustering.m
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/28/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSGDBFeature+AGSClustering.h"
#import <objc/runtime.h>
#import "AGSCluster.h"
#import "Common_int.h"

#define kClusterGraphicForGDBFeatureKey @"__clusterGDBFeatureKey"

@implementation AGSGDBFeature (AGSClustering)
-(BOOL)isCluster {
    return NO;
}

-(BOOL)isClusterCoverage {
    return self.owningCluster != nil;
}

-(AGSCluster *)owningCluster {
    return objc_getAssociatedObject(self, kClusterPayloadKey);
}

-(NSString *)idAttributeName {
    return objc_getAssociatedObject(self, kClusterGraphicCustomAttributeKey);
}

-(AGSGraphic *)graphicForGDBFeature {
    AGSGraphic *g = objc_getAssociatedObject(self, kClusterGraphicForGDBFeatureKey);
    if (g == nil) {
        g = [AGSGraphic graphicWithFeature:self];
        objc_setAssociatedObject(self, kClusterGraphicForGDBFeatureKey, g, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return g;
}

-(void)setIdAttributeName:(NSString *)idAttributeName {
    objc_setAssociatedObject(self, kClusterGraphicCustomAttributeKey, idAttributeName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(id)clusterItemKey {
    
	static NSString *oidFieldName = @"FID";
    
    NSUInteger result = self.featureId;
    if (result == 0) {
        result = self.objectID;
    }
    
    if (result == 0) {
        if (self.idAttributeName) {
            @try {
                NSNumber *oid = [self attributeForKey:self.idAttributeName];
                if (oid) {
                    result = oid.unsignedIntegerValue;
                }
            }
            @catch (NSException *exception) {
                NSLog(@"If you set the 'idAttributeName' property, you MUST populate the AGSGDBFeature's attribute with an Unsigned Int > 0");
            }
        } else {
            // No id, but we can get a OID field
            oidFieldName = ((AGSGDBFeatureTable *)self.table).objectIdField;
            NSNumber *oid = [self attributeForKey:oidFieldName];
            if (oid) {
                result = oid.unsignedIntegerValue;
            } else {
                NSLog(@"Cannot find feature OID!");
            }
        }
    }
    
    if (result == 0) {
        
		// If we could not recover, let's say so.
        NSLog(@"Feature ID 0!!");
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Feature ID 0!!"
														message:nil
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
		[alert show];
    }
    
    return [NSString stringWithFormat:@"f%d", result];
}
@end