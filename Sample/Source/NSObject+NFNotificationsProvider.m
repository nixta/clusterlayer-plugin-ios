//
//  NSObject+NFNotificationsProvider.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 4/11/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "NSObject+NFNotificationsProvider.h"

@implementation NSObject (NFNotificationsProvider)
-(void)registerListener:(id)listener forNotifications:(NSDictionary *)notificationSelectors {
    for (id notificationName in notificationSelectors) {
        [[NSNotificationCenter defaultCenter] addObserver:listener
                                                 selector:NSSelectorFromString(notificationSelectors[notificationName])
                                                     name:notificationName
                                                   object:self];
    }
}

-(void)unRegisterListener:(id)listener fromNotifications:(NSArray *)notificationNames {
    for (id notificationName in notificationNames) {
        [[NSNotificationCenter defaultCenter] removeObserver:listener
                                                        name:notificationName
                                                      object:self];
    }
}
@end
