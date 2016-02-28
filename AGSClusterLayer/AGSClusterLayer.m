//
//  AGSClusterLayer.m
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClustering.h"
#import "AGSClusterLayer.h"
#import "AGSClusterGrid.h"
#import "AGSCluster.h"
#import "Common_int.h"
#import "NSArray+Utils.h"
#import "AGSGraphic+AGSClustering.h"
#import "AGSGDBFeature+AGSClustering.h"
#import <objc/runtime.h>

#pragma mark - Constants and Defines
#define kClusterRenderBlockParameterKey @"clusterBlock"
#define kCoverageRenderBlockParameterKey @"coverageBlock"

#define kLODLevelScale @"scale"
#define kLODLevelResolution @"resolution"
#define kLODLevelZoomLevel @"level"
#define kLODLevelCellSize @"cellSize"
#define kLODLevelGrid @"grid"

#define kDefaultMinClusterCount 2

#define kBatchQueryOperationQueryKey @"__batchquery"

NSString * const AGSClusterLayerClusteringProgressNotification = kClusterLayerClusteringNotification;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_PercentComplete = kClusterLayerClusteringNotification_Key_PercentComplete;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_TotalZoomLevels = kClusterLayerClusteringNotification_Key_TotalZoomLevels;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_CompletedZoomLevels = kClusterLayerClusteringNotification_Key_ZoomLevelsClustered;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_FeatureCount = kClusterLayerClusteringNotification_Key_FeatureCount;
NSString * const AGSClusterLayerClusteringProgressNotification_UserInfo_Duration = kClusterLayerClusteringNotification_Key_Duration;

NSString * const AGSClusterLayerDataLoadingErrorNotification = kClusterLayerDataLoadingErrorNotification;
NSString * const AGSClusterLayerDataLoadingErrorNotification_UserInfo_Error = kClusterLayerDataLoadingErrorNotification_Key_Error;

NSString * const AGSClusterLayerDataLoadingProgressNotification = kClusterLayerDataLoadingNotification;
NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_PercentComplete = kClusterLayerDataLoadingNotification_Key_PercentComplete;
NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_TotalRecordsToLoad = kClusterLayerDataLoadingNotification_Key_TotalRecords;
NSString * const AGSClusterLayerDataLoadingProgressNotification_UserInfo_RecordsLoaded = kClusterLayerDataLoadingNotification_Key_LoadedCount;

NSString * NSStringFromBool(BOOL boolValue) {
    return boolValue?@"Yes":@"No";
}

#pragma mark - Internal properties
@interface AGSClusterLayer () <AGSLayerCalloutDelegate, AGSFeatureLayerQueryDelegate, AGSLayerDelegate, AGSCalloutDelegate>

@property (nonatomic, strong) NSMutableDictionary *grids;
@property (nonatomic, strong) NSArray *sortedGridKeys;
@property (nonatomic, strong) AGSClusterGrid *gridForCurrentScale;
@property (nonatomic, readonly) AGSClusterGrid *maxZoomLevelGrid;

@property (nonatomic, strong) NSArray *lodData;

@property (nonatomic, weak) AGSLayer *graphicsLayer;
@property (nonatomic, strong) NSMutableDictionary *symbolGeneratorBlocks;
@property (nonatomic, assign, readwrite) BOOL willClusterAtCurrentScale;

@property (nonatomic, assign) BOOL loadsAllFeatures;

@property (nonatomic, assign) BOOL mapViewLoaded;
@property (nonatomic, assign) BOOL dataLoaded;
@property (nonatomic, assign) BOOL initialized;

@property (nonatomic, strong) NSNumber *maxZoomLevel;

@property (nonatomic, strong) AGSGDBSyncTask *syncTask;
@property (nonatomic, assign) NSUInteger maxRecordCount;
@property (nonatomic, strong) NSMutableSet *openQueries;
@property (nonatomic, assign) NSUInteger featureCountToLoad;
@property (nonatomic, assign) NSUInteger totalFeatureCountToLoad;
@property (nonatomic, strong) NSMutableArray *allFeatures;

@property (nonatomic, strong) NSMutableArray *clusteringGrids;
@property (nonatomic, strong) NSDate *clusteringStartTime;
@end


#pragma mark - Synthesizers
@implementation AGSClusterLayer
@synthesize willClusterAtCurrentScale = _willClusterAtCurrentScale;
@synthesize initialized = _initialized;

#pragma mark - Convenience Constructors

+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer {
    return [[AGSClusterLayer alloc] initWithFeatureLayer:featureLayer];
}

+(AGSClusterLayer *)clusterLayerForFeatureLayer:(AGSFeatureLayer *)featureLayer
                        usingClusterSymbolBlock:(AGSClusterSymbolGeneratorBlock)clusterBlock
                            coverageSymbolBlock:(AGSClusterSymbolGeneratorBlock)coverageBlock {
    AGSClusterLayer *clusterLayer = [AGSClusterLayer clusterLayerForFeatureLayer:featureLayer];
    if (clusterBlock) [clusterLayer.symbolGeneratorBlocks setObject:clusterBlock forKey:kClusterRenderBlockParameterKey];
    if (coverageBlock) [clusterLayer.symbolGeneratorBlocks setObject:coverageBlock forKey:kCoverageRenderBlockParameterKey];
    return clusterLayer;
}

+(AGSClusterLayer *)clusterLayerForGraphicsLayer:(AGSGraphicsLayer *)graphicsLayer {
    return [[AGSClusterLayer alloc] initWithGraphicsLayer:graphicsLayer];
}

+(AGSClusterLayer *)clusterLayerForGraphicsLayer:(AGSGraphicsLayer *)graphicsLayer
                         usingClusterSymbolBlock:(AGSClusterSymbolGeneratorBlock)clusterBlock
                             coverageSymbolBlock:(AGSClusterSymbolGeneratorBlock)coverageBlock {
    AGSClusterLayer *clusterLayer = [AGSClusterLayer clusterLayerForGraphicsLayer:graphicsLayer];
    if (clusterBlock) [clusterLayer.symbolGeneratorBlocks setObject:clusterBlock forKey:kClusterRenderBlockParameterKey];
    if (coverageBlock) [clusterLayer.symbolGeneratorBlocks setObject:coverageBlock forKey:kCoverageRenderBlockParameterKey];
    return clusterLayer;
}

+(AGSClusterLayer *)clusterLayerForFeatureTableLayer:(AGSFeatureTableLayer *)featureTableLayer {
    return [[AGSClusterLayer alloc] initWithFeatureTableLayer:featureTableLayer];
}


#pragma mark - Initializers
-(id)init {
    self = [super init];
    if (self) {

        self.clusteringEnabled = YES;
        self.loadsAllFeatures = YES;
        self.calloutDelegate = self;
        self.minClusterCount = kDefaultMinClusterCount;
        self.symbolGeneratorBlocks = [NSMutableDictionary dictionary];
        self.grids = [NSMutableDictionary dictionary];
        self.lodData = [self defaultLodData];
        self.openQueries = [NSMutableSet set];
        self.allFeatures = [NSMutableArray array];
        [self parseLodData];
    }
    return self;
}

-(id)initWithGraphicsLayer:(AGSGraphicsLayer *)graphicsLayer {
    self = [self init];
    if (self) {
        self.graphicsLayer = graphicsLayer;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self featureLayerLoaded:nil];
        });
    }
    return self;
}

-(id)initWithFeatureTableLayer:(AGSFeatureTableLayer *)featureTableLayer {
    self = [self init];
    if (self) {
        self.graphicsLayer = featureTableLayer;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self featureLayerLoaded:nil];
        });
    }
    return self;
}

-(id)initWithFeatureLayer:(AGSFeatureLayer *)featureLayer {
    self = [self init];
    if (self) {
        self.graphicsLayer = featureLayer;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(featureLayerLoaded:)
                                                     name:AGSLayerDidLoadNotification
                                                   object:featureLayer];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(featureLayerFailedToLoad:)
                                                     name:AGSLayerDidFailToLoadNotification
                                                   object:featureLayer];
    }
    return self;
}

#pragma mark - Internal Checks on the Graphics Layer Setup
-(void)setGraphicsLayer:(AGSGraphicsLayer *)graphicsLayer {
    _graphicsLayer = graphicsLayer;
    
    if ([graphicsLayer isMemberOfClass:[AGSGraphicsLayer class]] &&
        graphicsLayer && graphicsLayer.mapView && !graphicsLayer.mapView.loaded) {
        NSLog(@"Warning: The AGSMapView for the source GraphicsLayer is not yet loaded! Your layer will likely not cluster.");
    }
}

#pragma mark - Asynchronous Setup

-(void)featureLayerLoaded:(NSNotification *)notification {
    AGSClusterSymbolGeneratorBlock clusterGenBlock = self.symbolGeneratorBlocks[kClusterRenderBlockParameterKey];
    AGSClusterSymbolGeneratorBlock coverageGenBlock = self.symbolGeneratorBlocks[kCoverageRenderBlockParameterKey];
    self.symbolGeneratorBlocks = nil;
    
    AGSRenderer *sourceRenderer = nil;
    if ([self.graphicsLayer isKindOfClass:[AGSFeatureLayer class]]) {
        sourceRenderer = ((AGSFeatureLayer *)self.graphicsLayer).renderer;
    } else if ([self.graphicsLayer isKindOfClass:[AGSFeatureTableLayer class]]) {
        sourceRenderer = ((AGSFeatureTableLayer *)self.graphicsLayer).renderer;
    } else if ([self.graphicsLayer isKindOfClass:[AGSGraphicsLayer class]]) {
        sourceRenderer = ((AGSGraphicsLayer *)self.graphicsLayer).renderer;
    }

    if (sourceRenderer != nil) {
        self.renderer = [[AGSClusterLayerRenderer alloc] initWithRenderer:sourceRenderer
                                                         clusterSymbolBlock:clusterGenBlock
                                                        coverageSymbolBlock:coverageGenBlock];
    } else {
        NSLog(@"Source layer doesn't have a renderer that we could use. What did you pass in?!?");
    }

    self.graphicsLayer.visible = !self.clusteringEnabled;

    if ([self.graphicsLayer isKindOfClass:[AGSFeatureLayer class]]) {
        if (self.loadsAllFeatures) {
            // Load all the data up-front.
            // We are then not dependent on the underlying feature layer for data updates.
            
            AGSFeatureLayer *featureLayer = (AGSFeatureLayer *)self.graphicsLayer;
            self.syncTask = [[AGSGDBSyncTask alloc] initWithURL:featureLayer.URL credential:featureLayer.credential];
            __weak AGSFeatureLayer *weakFL = featureLayer;
            __weak AGSGDBSyncTask *weakTask = self.syncTask;
            __weak typeof(self) weakSelf = self;
            [self.syncTask setLoadCompletion:^(NSError *error) {
                if (error) {
                    NSLog(@"Couldn't load FeatureServiceInfo: %@", error.localizedDescription);
                } else {
                    weakSelf.maxRecordCount = weakTask.featureServiceInfo.maxRecordCount;
                    if (weakSelf.maxRecordCount == 0) {
                        weakSelf.maxRecordCount = 1000;
                    }
                    weakFL.queryDelegate = weakSelf;
                    AGSQuery *q = [AGSQuery query];
                    q.whereClause = @"1=1";
                    [weakFL queryIds:q];
                }
                weakSelf.syncTask = nil;
            }];
        } else {
            // Load as the underlying feature layer updates its data. We build an accumulative copy of all the data.
            self.graphicsLayer.opacity = 0.5;
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(featuresLoaded:)
                                                         name:AGSFeatureLayerDidLoadFeaturesNotification
                                                       object:self.graphicsLayer];
        }

        [self createBlankGridsForLods];
    } else if ([self.graphicsLayer isKindOfClass:[AGSFeatureTableLayer class]]) {
        AGSFeatureTableLayer *layer = (AGSFeatureTableLayer *)self.graphicsLayer;
        AGSFeatureTable *table = layer.table;
        AGSQuery *q = [AGSQuery query];
        q.whereClause = layer.definitionExpression;
        [table queryResultsWithParameters:q completion:^(NSArray *results, NSError *error) {
            [self addOrUpdateFeatures:results];
            [self createBlankGridsForLods];
            [self dataLoadCompleted];
        }];
    } else if ([self.graphicsLayer isKindOfClass:[AGSGraphicsLayer class]]) {
        AGSGraphicsLayer *sourceLayer = (AGSGraphicsLayer *)self.graphicsLayer;
        [self addOrUpdateFeatures:sourceLayer.graphics];
        [self createBlankGridsForLods];
        [self dataLoadCompleted];
    }
}

-(void)featureLayerFailedToLoad:(NSNotification *)notification {
    AGSFeatureLayer *featureLayer = (AGSFeatureLayer *)self.graphicsLayer;
    NSLog(@"FeatureLayer failed to load: %@", [featureLayer.error localizedDescription]);

    [[NSNotificationCenter defaultCenter] postNotificationName:AGSClusterLayerDataLoadingErrorNotification
                                                        object:self
                                                      userInfo:@{kClusterLayerDataLoadingErrorNotification_Key_Error: featureLayer.error}];
}

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didQueryObjectIdsWithResults:(NSArray *)objectIds {
    NSUInteger count = 0;
    NSUInteger pageCount = 0;
    NSMutableArray *pagesToLoad = [NSMutableArray array];
    NSMutableArray *currentObjectIds = nil;
    for (NSNumber *oid in objectIds) {
        if (count % self.maxRecordCount == 0) {
            currentObjectIds = [NSMutableArray array];
            [pagesToLoad addObject:currentObjectIds];
            pageCount++;
        }
        [currentObjectIds addObject:oid];
        count++;
    }
    self.featureCountToLoad = count;
    self.totalFeatureCountToLoad = count;

    for (NSArray *featureIds in pagesToLoad) {
        AGSQuery *q = [AGSQuery query];
        q.objectIds = featureIds;
        q.returnGeometry = YES;
        q.outSpatialReference = self.mapView.spatialReference;
        NSOperation *queryOp = [featureLayer queryFeatures:q];
        objc_setAssociatedObject(queryOp, kBatchQueryOperationQueryKey, q, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self.openQueries addObject:queryOp];
    }
}

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didFailQueryObjectIdsWithError:(NSError *)error {
	NSLog(@"Could not get object IDs to load, %@",[error localizedDescription]);
}

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didQueryFeaturesWithFeatureSet:(AGSFeatureSet *)featureSet {
    [self addOrUpdateFeatures:featureSet.features];
    [self continueLoadingFeatures:op];
}

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didFailQueryFeaturesWithError:(NSError *)error {
    NSLog(@"Could not load features, %@",[error localizedDescription]);
    [self continueLoadingFeatures:op];
}

-(void)continueLoadingFeatures:(NSOperation *)op {
    AGSQuery *q = objc_getAssociatedObject(op, kBatchQueryOperationQueryKey);
    [self.openQueries removeObject:op];
    self.featureCountToLoad -= q.objectIds.count;
    NSUInteger featuresLoaded = self.totalFeatureCountToLoad - self.featureCountToLoad;
    double percentComplete = 100.0f * featuresLoaded / self.totalFeatureCountToLoad;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kClusterLayerDataLoadingNotification
                                                        object:self
                                                      userInfo:@{kClusterLayerDataLoadingNotification_Key_TotalRecords: @(self.totalFeatureCountToLoad),
                                                                 kClusterLayerDataLoadingNotification_Key_LoadedCount: @(featuresLoaded),
                                                                 kClusterLayerDataLoadingNotification_Key_PercentComplete: @(percentComplete)}];
    
    if (self.openQueries.count == 0) {
        [self dataLoadCompleted];
    }
}

-(void)dataLoadCompleted {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.dataLoaded = YES;
        [self rebuildClusterGrid];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refresh];
        });
    });
}

-(void)addOrUpdateFeatures:(NSArray *)features {
    [self.allFeatures addObjectsFromArray:features];
}

#pragma mark - Update Hooks
-(void)featuresLoaded:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[AGSFeatureLayer class]]) {
        AGSFeatureLayer *featureLayer = notification.object;
        [self addOrUpdateFeatures:featureLayer.graphics];
        self.dataLoaded = YES;
        [self rebuildClusterGrid];
        [self refresh];
    }
}

-(NSString *)objectIdField {
    if ([self.graphicsLayer isKindOfClass:[AGSFeatureLayer class]]) {
        AGSFeatureLayer *featureLayer = (AGSFeatureLayer *)self.graphicsLayer;
        return featureLayer.objectIdField;
    } else {
        return @"FID";
    }
}

-(void)mapDidUpdate:(AGSMapUpdateType)updateType
{
    if (updateType == AGSMapUpdateTypeSpatialExtent) {
        self.mapViewLoaded = self.mapView.loaded;
        self.willClusterAtCurrentScale = self.mapView.mapScale > self.minScaleForClustering;
        if (self.initialized) {
            self.gridForCurrentScale = [self findGridForCurrentScale];
        }
    }
    [super mapDidUpdate:updateType];
}

#pragma mark - Map/Data Load tracking
-(BOOL)initialized {
    if (!_initialized) {
        [self initializeIfPossible];
    }
    return _initialized;
}

-(void)setInitialized:(BOOL)initialized {
    _initialized = initialized;
    if (_initialized) {
        self.gridForCurrentScale = [self findGridForCurrentScale];
    }
}

-(void)initializeIfPossible {
    if (!_initialized) {
        if (self.mapViewLoaded && self.dataLoaded) {
            self.initialized = YES;
        }
    }
}

#pragma mark - Current Grid
-(void)setGridForCurrentScale:(AGSClusterGrid *)gridForCurrentScale {
    if (_gridForCurrentScale != gridForCurrentScale) {
        _gridForCurrentScale = gridForCurrentScale;
        [self refresh];
    }
}

#pragma mark - Helpers
-(NSUInteger)findZoomLevelForScale:(double)scale {
    NSNumber *lastZoomLevel = nil;
    for (NSNumber *zoomLevel in [self.sortedGridKeys reverseObjectEnumerator]) {
        NSDictionary *d = self.grids[zoomLevel];
        double scaleForZoom = [d[kLODLevelScale] doubleValue];
        if (scale <= scaleForZoom) {
            // This is our ZoomLevel
            return [zoomLevel unsignedIntegerValue];
        }
        lastZoomLevel = zoomLevel;
    }
    return [lastZoomLevel unsignedIntegerValue];
}

-(NSUInteger)cellSizeForScale:(double)scale {
    return [self.grids[@([self findZoomLevelForScale:scale])][kLODLevelCellSize] unsignedIntegerValue];
}

#pragma mark - Property Overrides
-(void)setMapView:(AGSMapView *)mapView {
    [super setMapView:mapView];
    self.mapViewLoaded = self.mapView.loaded;
}

#pragma mark - Properties
-(void)setClusteringEnabled:(BOOL)clusteringEnabled {
    _clusteringEnabled = clusteringEnabled;
    [self refresh];
}

-(void)setShowsClusterCoverages:(BOOL)showClusterCoverages {
    _showsClusterCoverages = showClusterCoverages;
    [self refresh];
}

-(void)setWillClusterAtCurrentScale:(BOOL)willClusterAtCurrentScale {
    BOOL wasClusteringAtPreviousScale = _willClusterAtCurrentScale;
    if (willClusterAtCurrentScale != wasClusteringAtPreviousScale) {
        [self willChangeValueForKey:@"willClusterAtCurrentScale"];
    }
    _willClusterAtCurrentScale = willClusterAtCurrentScale;
    if (willClusterAtCurrentScale != wasClusteringAtPreviousScale) {
        [self didChangeValueForKey:@"willClusterAtCurrentScale"];
        [self refresh];
    }
}

-(BOOL)willClusterAtCurrentScale {
    return _willClusterAtCurrentScale;
}

-(AGSEnvelope *)envelopeForClustersAtZoomLevel:(NSUInteger)zoomLevel {
    AGSMutableEnvelope *envelope = nil;
    AGSClusterGrid *gridToZoomTo = self.grids[@(zoomLevel)][kLODLevelGrid];
    for (AGSCluster *cluster in gridToZoomTo.clusters) {
        AGSGeometry *coverage = cluster.coverageGraphic.geometry;
        if (!envelope) {
            envelope = [coverage.envelope mutableCopy];
        } else {
            [envelope unionWithEnvelope:coverage.envelope];
        }
    }
    return envelope;
}

-(AGSClusterGrid *)findGridForCurrentScale {
    return self.grids[@([self findZoomLevelForScale:self.mapView.mapScale])][kLODLevelGrid];
}

-(AGSClusterGrid *)maxZoomLevelGrid {
    return self.grids[self.maxZoomLevel][kLODLevelGrid];
}

+(BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"willClusterAtCurrentScale"]) {
        return NO;
    } else {
        return [super automaticallyNotifiesObserversForKey:key];
    }
}

#pragma mark - Layer Refresh
-(void)refresh {
    if (!self.initialized) return;
    
    [self refreshClusters];
    
    [super refresh];
}

-(void)refreshClusters {
    [self removeAllGraphics];
    [self renderClusters];
}

-(void)clearClusters {
    [self removeAllGraphics];
    [self.maxZoomLevelGrid removeAllItems];
}

#pragma mark - Cluster Generation and Display
-(void)rebuildClusterGrid {
    self.clusteringStartTime = [NSDate date];
    self.clusteringGrids = [NSMutableArray arrayWithArray:[self.grids.allValues map:^id(id obj) {
        return obj[kLODLevelGrid];
    }]];
    
    AGSClusterGrid *grid = self.maxZoomLevelGrid;
    [grid addItems:self.allFeatures];
}

-(void)gridClustered:(NSNotification *)notification {
    [self.clusteringGrids removeObject:notification.object];
    
    NSUInteger gridsClustered = self.grids.count - self.clusteringGrids.count;
    NSTimeInterval clusteringDuration = -[self.clusteringStartTime timeIntervalSinceNow];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kClusterLayerClusteringNotification
                                                            object:self
                                                          userInfo:@{
                                                                     kClusterLayerClusteringNotification_Key_Duration: @(clusteringDuration),
                                                                     kClusterLayerClusteringNotification_Key_PercentComplete: @(100*gridsClustered/self.grids.count),
                                                                     kClusterLayerClusteringNotification_Key_FeatureCount: @(self.allFeatures.count),
                                                                     kClusterLayerClusteringNotification_Key_TotalZoomLevels: @(self.grids.count),
                                                                     kClusterLayerClusteringNotification_Key_ZoomLevelsClustered: @(self.grids.count - self.clusteringGrids.count)
                                                                     }];
    });
}

-(void)renderClusters {
    NSMutableArray *coverageGraphics = [NSMutableArray array];
    NSMutableArray *clusterGraphics = [NSMutableArray array];
    NSMutableArray *featureGraphics = [NSMutableArray array];
    
    for (AGSCluster *cluster in self.gridForCurrentScale.clusters) {
        if (self.clusteringEnabled &&
            self.mapView.mapScale > self.minScaleForClustering &&
            cluster.featureCount >= self.minClusterCount) {
            // Draw as cluster.
            if ((self.showsClusterCoverages || cluster.showCoverage) && cluster.features.count > 2) {
                // Draw the coverage if need be
                AGSGraphic *coverageGraphic = cluster.coverageGraphic;
                coverageGraphic.symbol = [self.renderer symbolForFeature:coverageGraphic timeExtent:nil];
                [coverageGraphics addObject:coverageGraphic];
            }

            cluster.symbol = [self.renderer symbolForFeature:cluster timeExtent:nil];
            [clusterGraphics addObject:cluster];
        } else {
            // Draw as feature(s).
            if ([self.graphicsLayer isKindOfClass:[AGSFeatureTableLayer class]]) {
                for (AGSGDBFeature *feature in cluster.features) {
                    AGSGraphic *g = feature.graphicForGDBFeature;
                    g.symbol = [self.renderer symbolForFeature:feature timeExtent:nil];
                    [featureGraphics addObject:g];
                }
            } else {
                for (AGSGraphic *feature in cluster.features) {
                    feature.symbol = [self.renderer symbolForFeature:feature timeExtent:nil];
                    [featureGraphics addObject:feature];
                }
            }
        }
    }

    [self addGraphics:coverageGraphics];
    [self addGraphics:clusterGraphics];
    [self addGraphics:featureGraphics];
}

#pragma mark - UI/Callouts
-(BOOL)callout:(AGSCallout *)callout willShowForFeature:(id<AGSFeature>)feature layer:(AGSLayer<AGSHitTestable> *)layer mapPoint:(AGSPoint *)mapPoint {
    [self handleCalloutChange:callout];
    
    AGSCluster *cluster = [feature isMemberOfClass:[AGSCluster class]]?(AGSCluster *)feature:((AGSGraphic *)feature).owningCluster;
    
    if (cluster) {
        NSLog(@"%@ :: %d", cluster, cluster.featureCount);
        callout.title = @"Cluster";
        callout.detail = [NSString stringWithFormat:@"Cluster contains %d features", cluster.features.count];
        callout.accessoryButtonHidden = YES;
        callout.delegate = self;
        cluster.showCoverage = YES;
        [self refresh];
    } else {
        callout.title = @"Ordinary feature";
        callout.detail = @"Might have a bunch of attributes on it";
        callout.accessoryButtonHidden = NO;
    }
    
    return YES;
}

-(void)calloutWillDismiss:(AGSCallout *)callout {
    [self handleCalloutChange:callout];
}

-(void)handleCalloutChange:(AGSCallout *)callout {
    if (callout.representedFeature) {
        id feature = callout.representedFeature;
        AGSCluster *cluster = [feature isKindOfClass:[AGSCluster class]]?(AGSCluster *)feature:((AGSGraphic *)feature).owningCluster;
        if (cluster) {
            cluster.showCoverage = NO;
            [self refresh];
        }
    }
}

#pragma mark - Build All Grids
-(void)createBlankGridsForLods {
    CGFloat cellSizeInInches = 0.25;
    AGSUnits mapUnits = self.mapViewLoaded?AGSUnitsFromSpatialReference(self.mapView.spatialReference):AGSUnitsMeters;
    AGSUnits screenUnits = AGSUnitsInches;
    double cellSizeInMapUnits = AGSUnitsToUnits(cellSizeInInches, screenUnits, mapUnits);
    
    AGSClusterGrid *prevClusterGrid = nil;
    for (NSNumber *zoomLevel in self.sortedGridKeys) {
        NSMutableDictionary *d = self.grids[zoomLevel];
        double scale = [d[kLODLevelScale] doubleValue];
        NSUInteger cellSize = floor(cellSizeInMapUnits * scale);
        d[kLODLevelCellSize] = @(cellSize);
        
        AGSClusterGrid *gridForZoomLevel = [[AGSClusterGrid alloc] initWithCellSize:cellSize forClusterLayer:self];
        gridForZoomLevel.zoomLevel = zoomLevel;
        
        prevClusterGrid.gridForNextZoomLevel = gridForZoomLevel;
        gridForZoomLevel.gridForPrevZoomLevel = prevClusterGrid;
        
        d[kLODLevelGrid] = gridForZoomLevel;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridClustered:)
                                                     name:AGSClusterGridClusteredNotification
                                                   object:gridForZoomLevel];
        
        prevClusterGrid = gridForZoomLevel;
        self.maxZoomLevel = zoomLevel;
    }
}

#pragma mark - Demo LODs
-(void)parseLodData {
    for (NSDictionary *lodInfo in self.lodData) {
        [self.grids setObject:[NSMutableDictionary dictionaryWithDictionary:lodInfo]
                       forKey:lodInfo[kLODLevelZoomLevel]];
    }
    self.sortedGridKeys = [self.grids.allKeys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [((NSNumber *)obj1) compare:obj2];
    }];
}

-(NSArray *)defaultLodData {
    return @[
             @{
                 @"level": @(0),
                 @"resolution": @(156543.03392800014),
                 @"scale": @(591657527.591555)
                 },
             @{
                 @"level": @(1),
                 @"resolution": @(78271.51696399994),
                 @"scale": @(295828763.795777)
                 },
             @{
                 @"level": @(2),
                 @"resolution": @(39135.75848200009),
                 @"scale": @(147914381.897889)
                 },
             @{
                 @"level": @(3),
                 @"resolution": @(19567.87924099992),
                 @"scale": @(73957190.948944)
                 },
             @{
                 @"level": @(4),
                 @"resolution": @(9783.93962049996),
                 @"scale": @(36978595.474472)
                 },
             @{
                 @"level": @(5),
                 @"resolution": @(4891.96981024998),
                 @"scale": @(18489297.737236)
                 },
             @{
                 @"level": @(6),
                 @"resolution": @(2445.98490512499),
                 @"scale": @(9244648.868618)
                 },
             @{
                 @"level": @(7),
                 @"resolution": @(1222.992452562495),
                 @"scale": @(4622324.434309)
                 },
             @{
                 @"level": @(8),
                 @"resolution": @(611.4962262813797),
                 @"scale": @(2311162.217155)
                 },
             @{
                 @"level": @(9),
                 @"resolution": @(305.74811314055756),
                 @"scale": @(1155581.108577)
                 },
             @{
                 @"level": @(10),
                 @"resolution": @(152.87405657041106),
                 @"scale": @(577790.554289)
                 },
             @{
                 @"level": @(11),
                 @"resolution": @(76.43702828507324),
                 @"scale": @(288895.277144)
                 },
             @{
                 @"level": @(12),
                 @"resolution": @(38.21851414253662),
                 @"scale": @(144447.638572)
                 },
             @{
                 @"level": @(13),
                 @"resolution": @(19.10925707126831),
                 @"scale": @(72223.819286)
                 },
             @{
                 @"level": @(14),
                 @"resolution": @(9.554628535634155),
                 @"scale": @(36111.909643)
                 },
             @{
                 @"level": @(15),
                 @"resolution": @(4.77731426794937),
                 @"scale": @(18055.954822)
                 },
             @{
                 @"level": @(16),
                 @"resolution": @(2.388657133974685),
                 @"scale": @(9027.977411)
                 },
             @{
                 @"level": @(17),
                 @"resolution": @(1.1943285668550503),
                 @"scale": @(4513.988705)
                 },
             @{
                 @"level": @(18),
                 @"resolution": @(0.5971642835598172),
                 @"scale": @(2256.994353)
                 },
             @{
                 @"level": @(19),
                 @"resolution": @(0.29858214164761665),
                 @"scale": @(1128.497176)
                 }
             ];
}
@end