//
//  AGSClusterLayer.m
//  AGSCluseterLayer
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterLayer.h"
#import "AGSClusterGrid.h"
#import "AGSCluster.h"

@interface AGSClusterLayer () <AGSQueryTaskDelegate, AGSHitTestable>
@property (nonatomic, strong) AGSClusterGrid *grid;
@property (nonatomic, strong) AGSQueryTask *queryTask;
@property (nonatomic, strong) NSMutableArray *features;
@property (nonatomic, strong) NSMutableArray *dataOperations;
#if debug
@property (nonatomic, strong) AGSGraphicsLayer *extentLayer;
@property (nonatomic, strong) AGSSimpleFillSymbol *extentSymbol;
#endif
@end

@implementation AGSClusterLayer
+(AGSClusterLayer *)clusterLayerWithURL:(NSURL *)featureLayerURL {
    return [[AGSClusterLayer alloc] initWithURL:featureLayerURL];
}

+(AGSClusterLayer *)clusterLayerWithURL:(NSURL *)featureLayerURL credential:(AGSCredential *)cred {
    return [[AGSClusterLayer alloc] initWithURL:featureLayerURL credential:cred];
}

-(id)init {
    self = [super init];
    if (self) {
        self.features = [NSMutableArray array];
        self.dataOperations = [NSMutableArray array];
        self.showClusterCoverages = NO;
    }
    return self;
}

-(void)setQueryTask:(AGSQueryTask *)queryTask {
    _queryTask = queryTask;
    _queryTask.delegate = self;
}

-(id)initWithURL:(NSURL *)featureLayerURL {
    self = [self init];
    self.queryTask = [AGSQueryTask queryTaskWithURL:featureLayerURL];
    return self;
}

-(id)initWithURL:(NSURL *)featureLayerURL credential:(AGSCredential *)cred
{
    self = [self init];
    self.queryTask = [AGSQueryTask queryTaskWithURL:featureLayerURL credential:cred];
    return self;
}

-(void)setMapView:(AGSMapView *)mapView
{
    NSLog(@"Map View Set");
    [super setMapView:mapView];
#if debug
    self.extentLayer = [AGSGraphicsLayer graphicsLayer];
    [mapView addMapLayer:self.extentLayer];
    self.extentSymbol = [AGSSimpleFillSymbol simpleFillSymbolWithColor:[UIColor clearColor]
                                                          outlineColor:[UIColor colorWithRed:1
                                                                                       green:0
                                                                                        blue:0
                                                                                       alpha:0.7]];
#endif
}

-(BOOL)allowCallout {
    return YES;
}

-(BOOL)allowHitTest {
    return YES;
}

-(void)mapDidUpdate:(AGSMapUpdateType)updateType
{
    if (updateType == AGSMapUpdateTypeSpatialExtent) {
#if debug
        [self.extentLayer removeAllGraphics];
#endif
        [self removeAllGraphics];
        if (self.grid) {
            [self.grid removeAllFeatures];
        }
        NSUInteger hCells = 7;
        NSUInteger vCells = 12;
        AGSEnvelope *mapEnv = [self.mapView toMapEnvelope:CGRectMake(0, 0, self.mapView.layer.bounds.size.width/hCells, self.mapView.layer.bounds.size.height/vCells)];
        NSUInteger cellSize = floor((mapEnv.height + mapEnv.width)/2);
        
        self.grid = [[AGSClusterGrid alloc] initWithCellSize:cellSize];
        
        NSLog(@"Cell Size: %d", cellSize);

        NSLog(@"Map Extent Updated");
        AGSMutableEnvelope *e = [self.mapView.visibleAreaEnvelope mutableCopy];
        [e expandByFactor:1.1];
        [e expandByFactor:0.5 withAnchorPoint:[AGSPoint pointWithX:e.xmin y:e.ymax spatialReference:e.spatialReference]]; // TL
        [self requestDataForEnvelope:e];
        [e offsetByX:e.width y:0]; // TR
        [self requestDataForEnvelope:e];
        [e offsetByX:0 y:-e.height]; // BR
        [self requestDataForEnvelope:e];
        [e offsetByX:-e.width y:0]; // BL
        [self requestDataForEnvelope:e];
    }
    [super mapDidUpdate:updateType];
}

-(void)requestDataForEnvelope:(AGSEnvelope *)e {
    AGSQuery *q = [AGSQuery query];
    q.geometry = e;
    q.where = @"1=1";
    q.outFields = @[@"*"];
    q.returnGeometry = YES;
    [self.dataOperations addObject:[self.queryTask executeWithQuery:q]];
    NSLog(@"Querying for envelope (%d queries): %@", self.dataOperations.count, e);
#if debug
    [self.extentLayer addGraphic:[AGSGraphic graphicWithGeometry:[e copy]
                                                         symbol:self.extentSymbol
                                                      attributes:nil]];
#endif
}

-(void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation *)op didFailWithError:(NSError *)error {
    [self.dataOperations removeObject:op];
    NSLog(@"Query failed (%d remaining): %@", self.dataOperations.count, error);
    if (self.dataOperations.count == 0) {
        NSLog(@"%@", self.grid);
    }
}

-(void)queryTask:(AGSQueryTask *)queryTask operation:(NSOperation *)op didExecuteWithFeatureSetResult:(AGSFeatureSet *)featureSet {
    [self.dataOperations removeObject:op];
    NSLog(@"Query succeeded (%d remaining): %d", self.dataOperations.count, featureSet.features.count);
    for (id<AGSFeature> f in featureSet.features) {
        [self.grid addFeature:f];
    }
    if (self.dataOperations.count == 0) {
        [self displayClusters];
        NSLog(@"%@", self.grid);
    }
}

-(void) displayClusters {
    for (AGSCluster *cluster in self.grid.clusters) {
        AGSCompositeSymbol *s = [AGSCompositeSymbol compositeSymbol];
        AGSSimpleMarkerSymbol *backgroundSymbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor purpleColor] colorWithAlphaComponent:0.7]];
        backgroundSymbol.outline = nil;
        backgroundSymbol.size = CGSizeMake(20, 20);
        AGSTextSymbol *countSymbol = [AGSTextSymbol textSymbolWithText:[NSString stringWithFormat:@"%d", cluster.features.count]
                                                                 color:[UIColor whiteColor]];
        [s addSymbol:backgroundSymbol];
        [s addSymbol:countSymbol];
        AGSGraphic *g = [AGSGraphic graphicWithGeometry:cluster.location
                                                 symbol:s
                                             attributes:@{@"count": @(cluster.features.count)}];
        if (self.showClusterCoverages && cluster.features.count > 1) {
            AGSGeometry *coverageGeom = cluster.coverage;
            AGSSimpleFillSymbol *coverageSymbol = [AGSSimpleFillSymbol simpleFillSymbolWithColor:[[UIColor orangeColor] colorWithAlphaComponent:0.3]
                                                                                    outlineColor:[[UIColor orangeColor] colorWithAlphaComponent:0.7]];
            AGSGraphic *coverageGraphic = [AGSGraphic graphicWithGeometry:coverageGeom
                                                                   symbol:coverageSymbol
                                                               attributes:nil];
            [self addGraphic:coverageGraphic];
        }
        [self addGraphic:g];
    }
}
@end