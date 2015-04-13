clusterlayer-plugin-ios
=======================

A cluster layer extension to the [ArcGIS Runtime for iOS](https://developers.arcgis.com/ios/).

The gridding code is based heavily on [Leaflet.markercluster](https://github.com/Leaflet/Leaflet.markercluster/blob/master/src/DistanceGrid.js)

![App](clusterlayer-plugin-ios.png)

##Usage
1. Import `AGSClusterLayer.h`
2. Add an `AGSFeatureLayer` to the `AGSMapView`
3. Create an `AGSClusterLayer` with the `AGSFeatureLayer` and add it to the `AGSMapView`
``` ObjC
#import "AGSClusterLayer.h"

#define kGreyBasemap @"http://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer"
#define kGreyBasemapRef @"http://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer"

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.mapView addMapLayer:[AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:[NSURL URLWithString:kGreyBasemap]]];

    AGSFeatureLayer *featureLayer = [AGSFeatureLayer featureServiceLayerWithURL:[NSURL URLWithString:kFeatureLayerURL] mode:AGSFeatureLayerModeOnDemand];
    [self.mapView addMapLayer:featureLayer];
    
    self.clusterLayer = [AGSClusterLayer clusterLayerForFeatureLayer:featureLayer];
    [self.mapView addMapLayer:self.clusterLayer];
}
```

You can also use an `AGSGraphicsLayer` to load data into a cluster layer, but you need to do this in the `mapViewDidLoad:` delegate method of `AGSMapViewLayerDelegate`:

``` ObjC
    self.graphicsClusterLayer = [AGSClusterLayer clusterLayerForGraphicsLayer:graphicsLayer];
    self.graphicsClusterLayer.opacity = 0.3;
    [self.mapView addMapLayer:self.graphicsClusterLayer];
```