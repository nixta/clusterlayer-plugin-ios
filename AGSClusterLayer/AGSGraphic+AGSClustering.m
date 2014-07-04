//
//  AGSGraphic+AGSClustering.m
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/28/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSGraphic+AGSClustering.h"
#import <objc/runtime.h>
#import "AGSCluster.h"
#import "Common_int.h"

@implementation AGSGraphic (AGSClustering)
-(BOOL)isCluster {
    return NO;
}

-(BOOL)isClusterCoverage {
    return self.owningCluster != nil;
}

-(AGSCluster *)owningCluster {
    return objc_getAssociatedObject(self, kClusterPayloadKey);
}

-(id)clusterItemKey {
    
	static NSString *oidFieldName = @"FID";
    
    NSUInteger result = self.featureId;
    if (result == 0) {
        if (self.layer == nil ||
            ![self.layer respondsToSelector:@selector(objectIdField)]) {
            // No featureId (we're doubtless not on a featureLayer). Try to recover
            @try {
                NSNumber *oid = [self attributeForKey:oidFieldName];
                if (oid) {
                    result = oid.unsignedIntegerValue;
                }
            }
            @catch (NSException *exception) {
                NSLog(@"Could not read FeatureID: %@", exception);
            }
        } else {
            // No id, but we can get a OID field
            oidFieldName = [((id)self.layer) objectIdField];
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