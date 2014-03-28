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

@interface AGSSampleViewController () <AGSMapViewLayerDelegate>
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (nonatomic, strong) AGSClusterLayer *clusterLayer;
@property (weak, nonatomic) IBOutlet UISwitch *coverageSwitch;
@property (weak, nonatomic) IBOutlet UILabel *clusteringStatusLabel;
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
    [self.mapView addMapLayer:self.clusterLayer];
    self.clusterLayer.showClusterCoverages = self.coverageSwitch.on;
    self.clusterLayer.minScaleForClustering = 50000;
    
    [self.clusterLayer addObserver:self forKeyPath:@"isClustering" options:NSKeyValueObservingOptionNew context:nil];
    [self.mapView addObserver:self forKeyPath:@"mapScale" options:NSKeyValueObservingOptionNew context:nil];

    [self.mapView addMapLayer:[AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:[NSURL URLWithString:kGreyBasemapRef]]];
    
    [self.mapView zoomToEnvelope:[AGSEnvelope envelopeWithXmin:-8374937.880610
                                                         ymin:4844715.815690
                                                         xmax:-8355224.673174
                                                         ymax:4879706.758889
                                             spatialReference:[AGSSpatialReference webMercatorSpatialReference]]
                        animated:NO];
    self.mapView.layerDelegate = self;
}

-(void)mapViewDidLoad:(AGSMapView *)mapView {
    NSLog(@"%@", self.mapView.visibleAreaEnvelope);
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    self.clusteringStatusLabel.text = [NSString stringWithFormat:@"%@ (1:%.2f)", self.clusterLayer.willClusterAtCurrentScale?@"Clustering":@"Not Clustering", self.mapView.mapScale];
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
