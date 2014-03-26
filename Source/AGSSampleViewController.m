//
//  EQSViewController.m
//  Basemaps
//
//  Created by Nicholas Furness on 11/29/12.
//  Copyright (c) 2012 ESRI. All rights reserved.
//

#import "AGSSampleViewController.h"
#import <ArcGIS/ArcGIS.h>

#import "AGSClusterLayer.h"

#define kGreyBasemap @"http://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer"
#define kGreyBasemapRef @"http://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer"
#define kFeatureLayerURL @"http://services.arcgis.com/OfH668nDRN7tbJh0/arcgis/rest/services/Philadelphia_Healthy_Corner_Stores/FeatureServer/0"

@interface AGSSampleViewController () <AGSCalloutDelegate>
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (nonatomic, strong) AGSClusterLayer *clusterLayer;
@property (weak, nonatomic) IBOutlet UISwitch *coverageSwitch;
@end

@implementation AGSSampleViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    [self.mapView addMapLayer:[AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:[NSURL URLWithString:kGreyBasemap]]];

    
    AGSFeatureLayer *featureLayer = [AGSFeatureLayer featureServiceLayerWithURL:[NSURL URLWithString:kFeatureLayerURL] mode:AGSFeatureLayerModeOnDemand];
    [self.mapView addMapLayer:featureLayer];
    
    self.clusterLayer = [AGSClusterLayer clusterLayerForFeatureLayer:featureLayer];
    featureLayer.opacity = 0;
    self.clusterLayer.showClusterCoverages = self.coverageSwitch.on;
    [self.mapView addMapLayer:self.clusterLayer];

    [self.mapView addMapLayer:[AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:[NSURL URLWithString:kGreyBasemapRef]]];
    
    [self.mapView zoomToEnvelope:[AGSEnvelope envelopeWithXmin:-8374937.880610
                                                         ymin:4844715.815690
                                                         xmax:-8355224.673174
                                                         ymax:4879706.758889
                                             spatialReference:[AGSSpatialReference webMercatorSpatialReference]]
                        animated:NO];
}

- (IBAction)toggleCoverages:(id)sender {
    self.clusterLayer.showClusterCoverages = self.coverageSwitch.on;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
