//
//  AGSGraphic+AGSClustering.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/28/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
@class AGSCluster;

@interface AGSGDBFeature (AGSClustering)

//Determines whether the graphic is a cluster
@property (nonatomic, readonly) BOOL isCluster;
@property (nonatomic, readonly) BOOL isClusterCoverage;
@property (nonatomic, readonly) AGSCluster *owningCluster;

// Declare an attribute on the graphic that is an Unsigned Int.
// Only set this if there is no appropriate "FID" attribute on the graphic.
// It is only necessary to set this on Graphics in an AGSGraphicsLayer. Features in an
// AGSFeatureLayer will automatically determine the right ID field to use.
@property (nonatomic, strong) NSString *idAttributeName;

-(id)clusterItemKey;

@property (nonatomic, readonly) AGSGraphic *graphicForGDBFeature;
@end
