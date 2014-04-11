//
//  NSObject+AGSNotificationsProvider.h
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 4/11/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <Foundation/Foundation.h>

#define strSelector(a) NSStringFromSelector(@selector(a))

@interface NSObject (NFNotificationsProvider)
-(void)registerListener:(id)listener forNotifications:(NSDictionary *)notificationSelectors;
-(void)unRegisterListener:(id)listener fromNotifications:(NSArray *)notificationNames;
@end
