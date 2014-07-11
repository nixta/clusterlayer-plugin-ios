//
//  NSObject+NFNotificationsProvider.m
//
//  Created by Nicholas Furness on 4/11/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "NSObject+NFNotificationsProvider.h"

@implementation NSObject (NFNotificationsProvider)
#pragma mark - Registration of listeners to self
-(void)registerListener:(id)listener forNotifications:(NSDictionary *)notificationSelectorsByName {
    [NSObject __registerListener:listener onObject:self forNotifications:notificationSelectorsByName];
}

-(void)unRegisterListener:(id)listener fromNotifications:(NSArray *)notificationNames {
    [NSObject __unRegisterListener:listener onObject:self fromNotifications:notificationNames];
}

#pragma mark - Registration of self as listener to object or objects
-(void)registerAsListenerForNotifications:(NSDictionary *)notificationSelectorsByName onObjectOrObjects:(id)objectOrObjects {
    if (objectOrObjects) {
        for (id source in [objectOrObjects conformsToProtocol:@protocol(NSFastEnumeration)]?objectOrObjects:@[objectOrObjects]) {
            [NSObject __registerListener:self onObject:source forNotifications:notificationSelectorsByName];
        }
    } else {
        [NSObject __registerListener:self onObject:nil forNotifications:notificationSelectorsByName];
    }
}

-(void)unRegisterAsListenerFromNotifications:(NSArray *)notificationNames onObjectOrObjects:(id)objectOrObjects {
    if (objectOrObjects) {
        for (id source in [objectOrObjects conformsToProtocol:@protocol(NSFastEnumeration)]?objectOrObjects:@[objectOrObjects]) {
            [source __unRegisterListener:self onObject:source fromNotifications:notificationNames];
        }
    } else {
        [NSObject __unRegisterListener:self onObject:nil fromNotifications:notificationNames];
    }
}

#pragma mark - Internal Methods
+(void)__registerListener:(id)listener onObject:(id)source forNotifications:(NSDictionary *)notificationSelectorsByName {
    for (id notificationName in notificationSelectorsByName) {
        [[NSNotificationCenter defaultCenter] addObserver:listener
                                                 selector:NSSelectorFromString(notificationSelectorsByName[notificationName])
                                                     name:notificationName
                                                   object:source];
    }
}

+(void)__unRegisterListener:(id)listener onObject:(id)source fromNotifications:(NSArray *)notificationNames {
	for (id notificationName in notificationNames) {
        [[NSNotificationCenter defaultCenter] removeObserver:listener
                                                        name:notificationName
                                                      object:source];
    }
}
@end
