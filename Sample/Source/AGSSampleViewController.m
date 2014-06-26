//
//  EQSViewController.m
//  Basemaps
//
//  Created by Nicholas Furness on 11/29/12.
//  Copyright (c) 2012 ESRI. All rights reserved.
//

#import "AGSSampleViewController.h"
#import <ArcGIS/ArcGIS.h>
#import "AGSClustering.h"
#import "NSObject+NFNotificationsProvider.h"

#define kBasemap @"http://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer"
#define kFeatureLayerURL @"http://services.arcgis.com/OfH668nDRN7tbJh0/arcgis/rest/services/stops/FeatureServer/0"

@interface AGSSampleViewController ()
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (nonatomic, strong) AGSClusterLayer *clusterLayer;
@property (weak, nonatomic) IBOutlet UISwitch *coverageSwitch;
@property (weak, nonatomic) IBOutlet UILabel *clusteringStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *clusteringFeedbackLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *dataLoadProgressView;
@end

@implementation AGSSampleViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    [self.mapView addMapLayer:[AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:[NSURL URLWithString:kBasemap]]];
    
    AGSFeatureLayer *featureLayer = [AGSFeatureLayer featureServiceLayerWithURL:[NSURL URLWithString:kFeatureLayerURL] mode:AGSFeatureLayerModeOnDemand];
    [self.mapView addMapLayer:featureLayer];
    

    
    self.clusterLayer = [AGSClusterLayer clusterLayerForFeatureLayer:featureLayer];
    [self.mapView addMapLayer:self.clusterLayer];

    // Cluster layer config
    self.clusterLayer.showsClusterCoverages = self.coverageSwitch.on;
    self.clusterLayer.minScaleForClustering = 15000;

    
    
    AGSEnvelope *initialEnv = [AGSEnvelope envelopeWithXmin:-13743980.503617
                                                       ymin:5553033.545344
                                                       xmax:-13567177.320049
                                                       ymax:5845311.308181
                                           spatialReference:[AGSSpatialReference webMercatorSpatialReference]];
    [self.mapView zoomToEnvelope:initialEnv animated:NO];
    
    // Cluster layer events - this is all UI stuff...
    [self.clusterLayer registerListener:self
                       forNotifications:@{AGSClusterLayerDataLoadingProgressNotification: strSelector(dataLoadProgress:),
                                          AGSClusterLayerDataLoadingErrorNotification: strSelector(dataLoadError:),
                                          AGSClusterLayerClusteringProgressNotification: strSelector(clusteringProgress:)}];
    
    [self.clusterLayer addObserver:self forKeyPath:@"willClusterAtCurrentScale" options:NSKeyValueObservingOptionNew context:nil];
    [self.mapView addObserver:self forKeyPath:@"mapScale" options:NSKeyValueObservingOptionNew context:nil];
}

-(void)dataLoadProgress:(NSNotification *)notification {

    double percentComplete = [notification.userInfo[AGSClusterLayerDataLoadingProgressNotification_UserInfo_PercentComplete] doubleValue];
    NSUInteger featuresLoaded = [notification.userInfo[AGSClusterLayerDataLoadingProgressNotification_UserInfo_RecordsLoaded] unsignedIntegerValue];
    NSUInteger totalFeaturesToLoad = [notification.userInfo[AGSClusterLayerDataLoadingProgressNotification_UserInfo_TotalRecordsToLoad] unsignedIntegerValue];
    
    [self.dataLoadProgressView setProgress:percentComplete/100 animated:YES];
    
    if (percentComplete == 100) {
        NSLog(@"Done loading %d features", featuresLoaded);
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
        NSLog(@"Done clustering features in %.4fs", duration);
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

-(void)dataLoadError:(NSNotification *)notification {
    
	NSError *error = notification.userInfo[AGSClusterLayerDataLoadingErrorNotification_UserInfo_Error];
    NSString *strError = error.localizedDescription;
    if (strError.length == 0) strError = error.localizedFailureReason;
    [[[UIAlertView alloc] initWithTitle:@"Cluster Load Error"
                                message:strError
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    self.clusteringStatusLabel.text = [NSString stringWithFormat:@"%@ (1:%.2f)", self.clusterLayer.willClusterAtCurrentScale?@"Clustering":@"Not Clustering", self.mapView.mapScale];
}

- (IBAction)toggleCoverages:(id)sender {
    self.clusterLayer.showsClusterCoverages = self.coverageSwitch.on;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
