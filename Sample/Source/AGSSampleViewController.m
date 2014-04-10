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

#define kBasemap @"http://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer"
#define kFeatureLayerURL @"http://services.arcgis.com/rOo16HdIMeOBI4Mb/arcgis/rest/services/stops/FeatureServer/0"

@interface AGSSampleViewController ()
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (nonatomic, strong) AGSClusterLayer *clusterLayer;
@property (weak, nonatomic) IBOutlet UISwitch *coverageSwitch;
@property (weak, nonatomic) IBOutlet UILabel *clusteringStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *clusteringFeedbackLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *dataLoadProgressView;
@end

@implementation AGSSampleViewController {
    BOOL _initialZoomDone;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    [self.mapView addMapLayer:[AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:[NSURL URLWithString:kBasemap]]];
    
    AGSFeatureLayer *featureLayer = [AGSFeatureLayer featureServiceLayerWithURL:[NSURL URLWithString:kFeatureLayerURL] mode:AGSFeatureLayerModeOnDemand];
    [self.mapView addMapLayer:featureLayer];
    
    self.clusterLayer = [AGSClusterLayer clusterLayerForFeatureLayer:featureLayer];
    [self.mapView addMapLayer:self.clusterLayer];
    
    self.clusterLayer.showClusterCoverages = self.coverageSwitch.on;
    self.clusterLayer.minScaleForClustering = 14000;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dataLoadProgress:)
                                                 name:AGSClusterLayerLoadFeaturesProgressNotification
                                               object:self.clusterLayer];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clusteringProgress:)
                                                 name:AGSClusterLayerClusteringProgressNotification
                                               object:self.clusterLayer];
    
    [self.clusterLayer addObserver:self forKeyPath:@"willClusterAtCurrentScale" options:NSKeyValueObservingOptionNew context:nil];
    [self.mapView addObserver:self forKeyPath:@"mapScale" options:NSKeyValueObservingOptionNew context:nil];
    
    AGSEnvelope *initialEnv = [AGSEnvelope envelopeWithXmin:-13743980.503617
                                                       ymin:5553033.545344
                                                       xmax:-13567177.320049
                                                       ymax:5845311.308181
                                           spatialReference:[AGSSpatialReference webMercatorSpatialReference]];
    [self.mapView zoomToEnvelope:initialEnv animated:NO];
}

-(void)dataLoadProgress:(NSNotification *)notification {
    double percentComplete = [notification.userInfo[AGSClusterLayerLoadFeaturesProgressNotification_UserInfo_PercentComplete] doubleValue];
    NSUInteger featuresLoaded = [notification.userInfo[AGSClusterLayerLoadFeaturesProgressNotification_UserInfo_RecordsLoaded] unsignedIntegerValue];
    NSUInteger totalFeaturesToLoad = [notification.userInfo[AGSClusterLayerLoadFeaturesProgressNotification_UserInfo_TotalRecordsToLoad] unsignedIntegerValue];
    
    [self.dataLoadProgressView setProgress:percentComplete/100 animated:YES];
    
    if (percentComplete == 100) {
        self.dataLoadProgressView.backgroundColor = self.dataLoadProgressView.tintColor;
        self.dataLoadProgressView.tintColor = [UIColor colorWithRed:0.756 green:0.137 blue:0.173 alpha:1.000];
        [self.dataLoadProgressView setProgress:0 animated:NO];
    }
    
    self.clusteringFeedbackLabel.text = [NSString stringWithFormat:@"Loading data: %.2f%% complete (%d of %d features)", percentComplete, featuresLoaded, totalFeaturesToLoad];
}

-(void)clusteringProgress:(NSNotification *)notification {
    double percentComplete = [notification.userInfo[AGSClusterLayerClusteringProgressNotification_UserInfo_PercentComplete] doubleValue];
    NSTimeInterval duration = [notification.userInfo[AGSClusterLayerClusteringProgressNotification_UserInfo_Duration] doubleValue];
    
    [self.dataLoadProgressView setProgress:percentComplete/100 animated:YES];
    
    if (percentComplete == 100) {
        self.clusteringFeedbackLabel.text = [NSString stringWithFormat:@"Clustering complete in %.2fs", duration];
        [UIView animateWithDuration:0.2
                         animations:^{
                             self.dataLoadProgressView.alpha = 0;
                         }
                         completion:^(BOOL finished) {
                             self.dataLoadProgressView.hidden = YES;
                         }];
    } else {
        self.clusteringFeedbackLabel.text = [NSString stringWithFormat:@"Clustering zoom levels %.4fs", duration];
    }
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
