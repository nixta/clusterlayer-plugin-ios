//
//  NSObject+AGSNotificationsProvider.h
//
//  Created by Nicholas Furness on 4/11/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>

#define strSelector(a) NSStringFromSelector(@selector(a))

@interface NSObject (NFNotificationsProvider)
#pragma mark - Register listener on caller object
-(void)registerListener:(id)listener forNotifications:(NSDictionary *)notificationSelectorsByName;
-(void)unRegisterListener:(id)listener fromNotifications:(NSArray *)notificationNames;

#pragma mark - Register caller as listener on defined object(s)
-(void)registerAsListenerForNotifications:(NSDictionary *)notificationSelectorsByName onObjectOrObjects:(id)objectOrObjects;
-(void)unRegisterAsListenerFromNotifications:(NSArray *)notificationNames onObjectOrObjects:(id)objectOrObjects;
@end
