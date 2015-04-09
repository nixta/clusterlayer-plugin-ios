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

@interface AGSSampleViewController () <AGSMapViewLayerDelegate>
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (nonatomic, strong) AGSClusterLayer *clusterLayer;
@property (nonatomic, strong) AGSClusterLayer *graphicsClusterLayer;
@property (weak, nonatomic) IBOutlet UISwitch *coverageSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *clusteringSwitch;
@property (weak, nonatomic) IBOutlet UILabel *clusteringStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *clusteringFeedbackLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *dataLoadProgressView;
@property (weak, nonatomic) IBOutlet UILabel *clusteringEnabledLabel;
@end

@implementation AGSSampleViewController

-(double)randomDoubleBetween:(double)smallNumber and:(double)bigNumber {
    double diff = bigNumber - smallNumber;
    return (((double) (arc4random() % ((unsigned)RAND_MAX + 1)) / RAND_MAX) * diff) + smallNumber;
}

-(AGSPoint *)randomPointInEnvelope:(AGSEnvelope *)envelope {
    return [AGSPoint pointWithX:[self randomDoubleBetween:envelope.xmax and:envelope.xmin]
                              y:[self randomDoubleBetween:envelope.ymin and:envelope.ymax]
               spatialReference:envelope.spatialReference];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    [self.mapView addMapLayer:[AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:[NSURL URLWithString:kBasemap]]];

    // Must add the source layer to connect it to its end point.
    AGSFeatureLayer *featureLayer = [AGSFeatureLayer featureServiceLayerWithURL:[NSURL URLWithString:kFeatureLayerURL] mode:AGSFeatureLayerModeOnDemand];
    [self.mapView addMapLayer:featureLayer];

    
    
    /// *******************************
    /// Cluster Layer Setup

    // Now wrap it in an AGSClusterLayer. The original FeatureLayer will be hidden in the map.
    self.clusterLayer = [AGSClusterLayer clusterLayerForFeatureLayer:featureLayer];
    [self.mapView addMapLayer:self.clusterLayer];

    // Cluster layer config
    self.clusterLayer.minScaleForClustering = 15000;
    
    /// *******************************

    
    
    
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
    self.clusterLayer.showsClusterCoverages = self.coverageSwitch.on;
    
    
    self.mapView.layerDelegate = self;
}

-(void)mapViewDidLoad:(AGSMapView *)mapView {
    AGSEnvelope *initialEnv = mapView.visibleAreaEnvelope;
    
    // Note, we need to add the GraphicsLayer after the AGSMapView has loaded so we know there's a spatial reference
    // we can use. You will see a warning in the console logs if you don't.
    AGSGraphicsLayer *graphicsLayer = [AGSGraphicsLayer graphicsLayer];
    NSInteger numberOfRecords = 10000;
    NSInteger currentOID = 1;
    AGSSimpleMarkerSymbol *symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor orangeColor] colorWithAlphaComponent:0.75]];
    symbol.outline = nil;
    symbol.style = AGSSimpleMarkerSymbolStyleCircle;
    symbol.size = CGSizeMake(4, 4);
    
    for (NSInteger i = 0; i < numberOfRecords; i++) {
        AGSPoint *newPoint = [self randomPointInEnvelope:initialEnv];
        [graphicsLayer addGraphic:[AGSGraphic graphicWithGeometry:newPoint symbol:symbol attributes:@{
                                                                                                      @"FID": @(currentOID)
                                                                                                      }]];
        currentOID++;
    }
    
    graphicsLayer.renderer = [AGSSimpleRenderer simpleRendererWithSymbol:symbol];
    
    NSLog(@"Created %d features!", graphicsLayer.graphicsCount);
    
    [self.mapView addMapLayer:graphicsLayer];

    /// *******************************
    /// Cluster Layer Setup
    
    // Now wrap it in an AGSClusterLayer. The original GraphicsLayer will be hidden in the map.
    self.graphicsClusterLayer = [AGSClusterLayer clusterLayerForGraphicsLayer:graphicsLayer];
    self.graphicsClusterLayer.opacity = 0.3;
    [self.mapView insertMapLayer:self.graphicsClusterLayer atIndex:[self.mapView.mapLayers indexOfObject:self.clusterLayer]];
    
    // Cluster layer config
    self.graphicsClusterLayer.minScaleForClustering = 15000;
    /// *******************************
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

- (IBAction)toggleClustering {
    self.clusterLayer.clusteringEnabled = self.clusteringSwitch.on;
    self.coverageSwitch.enabled = self.clusterLayer.clusteringEnabled;
    self.clusteringEnabledLabel.text = [NSString stringWithFormat:@"Clustering %@", self.clusterLayer.clusteringEnabled?@"Enabled":@"Disabled"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL)prefersStatusBarHidden {
    return YES;
}
@end
