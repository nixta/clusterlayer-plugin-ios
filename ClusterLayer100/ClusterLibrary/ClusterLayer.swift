// Copyright 2019 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import ArcGIS

let agsBuild: Int = {
    let bundleBuildStr = AGSBundle()?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    if let bundleBuildStr = bundleBuildStr, let bundleBuild = Int(bundleBuildStr) {
        return bundleBuild
    }
    return 0
}()

fileprivate let clusterTableFields: [AGSField] = [
    AGSField(fieldType: .int32, name: "Key", alias: "Key", length: 0, domain: nil, editable: true, allowNull: false),
    AGSField(fieldType: .int16, name: "FeatureCount", alias: "Feature Count", length: 0, domain: nil, editable: true, allowNull: false),
    AGSField(fieldType: .int16, name: "ShouldDisplayItems", alias: "Display Exploded", length: 0, domain: nil, editable: true, allowNull: false)
]

fileprivate enum ClusterDisplay: CustomStringConvertible {
    case clusters
    case coverages
    case items
    
    var description: String {
        switch self {
        case .clusters:
            return "Clusters"
        case .coverages:
            return "Coverages"
        case .items:
            return "Items"
        }
    }
}

extension ClusterLayer {
    class func clusterLayer(for featureLayer: AGSFeatureLayer, completion: (ClusterLayer?)->Void) {
        
    }
}

class ClusterLayer<M: ClusterManager>: AGSFeatureCollectionLayer {
    typealias T = M.ItemType
    
    let manager: M!
    
    let sourceLayer: AGSFeatureLayer!
    
    var mapScaleObserver: NSKeyValueObservation!

    var currentClusterProvider: M.ClusterProviderType?
    
    var centroidSymbol: AGSSymbol = getCentroidSymbol() {
        didSet {
            centroidsTable.renderer = AGSSimpleRenderer(symbol: centroidSymbol)
        }
    }
    var coverageSymbol: AGSSymbol = defaultCoverageSymbol {
        didSet {
            coveragesTable.renderer = AGSSimpleRenderer(symbol: coverageSymbol)
        }
    }
    
    let minClusterCount: Int = 3
    
    private let centroidsTable: AGSFeatureCollectionTable = {
        let table = AGSFeatureCollectionTable(fields: clusterTableFields,
                                                      geometryType: .point,
                                                      spatialReference: AGSSpatialReference.webMercator())
        table.displayName = "Clusters Table"
        let classBreakSmall = AGSClassBreak(description: "Small", label: "Small Cluster",
                                       minValue: 0, maxValue: 50,
                                       symbol: getCentroidSymbol())
        let classBreakMedium = AGSClassBreak(description: "Medium", label: "MEdium Cluster",
                                       minValue: 99, maxValue: 999,
                                       symbol: getCentroidSymbol(sizeFactor: 1.2, color: mediumClusterColor))
        let classBreakLarge = AGSClassBreak(description: "Large", label: "Large Cluster",
                                       minValue: 1000, maxValue: 1E6,
                                       symbol: getCentroidSymbol(sizeFactor: 1.3, color: largeClusterColor))
        table.renderer = AGSClassBreaksRenderer(fieldName: "FeatureCount", classBreaks: [classBreakSmall, classBreakMedium, classBreakLarge])
        return table
    }()
    
    private let coveragesTable: AGSFeatureCollectionTable = {
        let table = AGSFeatureCollectionTable(fields: clusterTableFields, geometryType: .polygon, spatialReference: AGSSpatialReference.webMercator())
        table.displayName = "Coverages Table"
        let classBreak = AGSClassBreak(description: "Clustered", label: "Clustered",
                                       minValue: 5, maxValue: 1E6,
                                       symbol: defaultCoverageSymbol)
        table.renderer = AGSClassBreaksRenderer(fieldName: "FeatureCount", classBreaks: [classBreak])
        return table
    }()
    
    private let unclusteredItemsTable: AGSFeatureCollectionTable
    
    private(set) var clusterPointLayer: AGSFeatureLayer?
    private(set) var clusterCoverageLayer: AGSFeatureLayer?
    private(set) var unclusteredItemsLayer: AGSFeatureLayer?
    
    init(mapView: AGSMapView, featureLayer: AGSFeatureLayer) {
        guard let sourceTable = featureLayer.featureTable else {
            preconditionFailure("Feature Layer has no source table: \(featureLayer.name)")
        }
        
        guard sourceTable.loadStatus == .loaded else {
            preconditionFailure("Feature Layer's source Feature Table must be loaded: \(featureLayer.name)")
        }
        
        guard sourceTable.geometryType != .unknown else {
            preconditionFailure("Feature Layer GeometryType is unknown: \(sourceTable.tableName)")
        }

        manager = M(mapView: mapView)
        
        sourceLayer = featureLayer
        
        unclusteredItemsTable = AGSFeatureCollectionTable(featureTable: sourceTable)
        unclusteredItemsTable.renderer = featureLayer.renderer?.copy() as? AGSRenderer
        
        let tables = [unclusteredItemsTable, coveragesTable, centroidsTable]
        
        super.init(featureCollection: AGSFeatureCollection(featureCollectionTables: tables))
        
        unclusteredItemsLayer = layers[0]
        clusterCoverageLayer = layers[1]
        clusterPointLayer = layers[2]

        featureLayer.load { [weak self] (error) in
            guard error == nil else { return }
            self?.minScale = featureLayer.minScale
            self?.maxScale = featureLayer.maxScale
        }
        
        let textSymbol = AGSTextSymbol(text: "", color: .white, size: fontSize, horizontalAlignment: .center, verticalAlignment: .middle)
        if let ld = try? AGSLabelDefinition.with(fieldName: "FeatureCount", textSymbol: textSymbol) {
            clusterPointLayer?.labelDefinitions.add(ld)
            clusterPointLayer?.labelsEnabled = true
        }
        
        let initializationGroup = DispatchGroup()
        initializationGroup.enter()
        initializationGroup.enter()
        initializationGroup.enter()

        let sourceParams = AGSQueryParameters()
        sourceParams.whereClause = "1=1"
        
        sourceLayer.featureTable?.queryFeatures(with: sourceParams, completion: { [weak self, initializationGroup] (sourceFeatureResults, error) in
            defer { initializationGroup.leave() }
            
            if let error = error {
                print("Error querying source features: \(error.localizedDescription)")
                return
            }
            
            guard let self = self, let sourceFeatures = sourceFeatureResults?.featureEnumerator().allObjects as? [T] else { return }

            self.manager.add(items: sourceFeatures)
        })
        
        AGSLoadObjects(tables) { [initializationGroup] (_) in
            for errorTable in tables.filter({ $0.loadError != nil }) {
                print("Error loading table '\(errorTable.tableName)': \(errorTable.loadError!)")
            }
            initializationGroup.leave()
        }

        if mapView.mapScale.isNaN {
            print("mapScale is NaN!!!!")
            mapScaleObserver = mapView.observe(\.mapScale, options: [.initial, .new], changeHandler: { [weak self, initializationGroup] (changedMapView, change) in
                guard !changedMapView.mapScale.isNaN else { return }
                print("mapScale WAS NaN - is now \(changedMapView.mapScale)...")
                self?.mapScaleObserver?.invalidate()
                self?.mapScaleObserver = nil
                initializationGroup.leave()
            })
        } else {
            initializationGroup.leave()
        }
        
        initializationGroup.notify(queue: .main) { [weak self] in
            
            guard let self = self else { return }
            
            guard let clusterProviderForScale = self.manager.clusterProvider(for: mapView.mapScale) else {
                print("Unable to set initial cluster LOD (mapScape = \(mapView.mapScale))")
                return
            }
            
            self.currentClusterProvider = clusterProviderForScale
            
            self.updateDisplay(for: mapView)
            
            self.mapScaleObserver = mapView.observe(\.mapScale, options: [.new], changeHandler: { [weak self] (changedMapView, change) in
                // AGSMapView emits many mapScale changes. We want to wait until the map isn't changing any more…
                DispatchQueue.main.debounce(interval: 0.2, context: changedMapView, action: {
                    guard let self = self else { return }
                    
                    guard (self.minScale == 0 && self.maxScale == 0) || (self.minScale < changedMapView.mapScale && self.maxScale > changedMapView.mapScale) else {
                        print("Map Scale out of visible range: \(self.minScale) < \(changedMapView.mapScale) < \(self.maxScale)")
                        return
                    }
                    
                    guard let clusterProviderForScale = self.manager.clusterProvider(for: changedMapView.mapScale),
                        clusterProviderForScale != self.currentClusterProvider else {
                            print("Cluster Provider is unchanged after map navigation (Map Scale \(changedMapView.mapScale))")
                            return
                    }
                    
                    self.currentClusterProvider = clusterProviderForScale
                    
                    self.updateDisplay(for: changedMapView)
                })
            })
            
        }
        
    }
    
    func updateDisplay(for mapView: AGSMapView) {

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.currentClusterProvider?.ensureClustersReadyForDisplay()
            
            self.updateClusterDisplay(component: .clusters, mapView: mapView)
            self.updateClusterDisplay(component: .items, mapView: mapView)
//            self.updateClusterDisplay(component: .coverages, mapView: mapView)
        }

    }
    
    private func updateClusterDisplay(component: ClusterDisplay, mapView: AGSMapView) {
        
        let table: AGSFeatureCollectionTable = {
            switch component {
            case .clusters:
                return centroidsTable
            case .coverages:
                return coveragesTable
            case .items:
                return unclusteredItemsTable
            }
        }()
        
        // Get currently displayed clusters
        let params = AGSQueryParameters.queryForAll()
        table.queryFeatures(with: params, completion: { [weak self] (result, error) in
            if let error = error {
                print("Error querying features to delete \(error.localizedDescription)")
                return
            }
            
            guard let self = self else { return }
            
            // Get all the clusters to remove from display.
            guard let featuresToRemove = result?.featureEnumerator().allObjects else { return }
            let featuresToAdd = self.currentClusterProvider?.clusters.asFeatures(in: table, for: component, minClusterCount: self.minClusterCount)

            let addRemoveGroup = DispatchGroup()
            addRemoveGroup.enter()
            addRemoveGroup.enter()
            
            // Remove previous LOD's clusters from display.
            table.delete(featuresToRemove, completion: { (error) in
                addRemoveGroup.leave()
                if let error = error {
                    print("Error deleting features: \(error.localizedDescription)")
                    return
                }
            })
            
            // Add new LOD's clusters to display.
            if let featuresToAdd = featuresToAdd {
                table.add(featuresToAdd, completion: { error in
                    addRemoveGroup.leave()
                    if let error = error {
                        print("Error adding features for new map scale: \(error.localizedDescription)")
                        return
                    }
                })
            } else {
                addRemoveGroup.leave()
            }
            
            addRemoveGroup.notify(queue: .main) {
                print("Just removed \(featuresToRemove.count) and added \(featuresToAdd?.count ?? 0) \(component)")
            }
        })

    }
    
    deinit {
        mapScaleObserver.invalidate()
        mapScaleObserver = nil
    }
}

extension AGSFeatureCollectionTable {
    convenience init(featureTable: AGSFeatureTable) {
        self.init(fields: featureTable.fields,
        geometryType: featureTable.geometryType,
        spatialReference: featureTable.spatialReference,
        hasZ: featureTable.hasZ, hasM: featureTable.hasM)
    }
}


extension Set where Element: Cluster {
    fileprivate func asFeatures(in table: AGSFeatureTable, for displayType: ClusterDisplay, minClusterCount: Int = 2) -> [AGSFeature] {
        switch displayType {
        case .items:
            return self.flatMap({ (cluster) -> [AGSFeature] in
                if cluster.itemCount < minClusterCount {
                    // If we should be displaying the features, return them
                    return cluster.items.compactMap({ (item) -> AGSFeature? in
                        return item as? AGSFeature
                    })
                } else {
                    // We should be displaying as a cluster, so don't return any items.
                    return []
                }
            })
        case .clusters, .coverages:
            return self.compactMap({ (cluster) -> AGSFeature? in
                guard let geometry: AGSGeometry? = {
                    switch displayType {
                    case .clusters:
                        // If we should explode the cluster, return nil for the cluster geometry.
                        // A separate call to this function with displayType == .items will then
                        // make sure the features are displayed.
                        if cluster.itemCount >= minClusterCount {
                            return cluster.centroid
                        } else {
                            return nil
                        }
                    case .coverages:
                        return cluster.coverage
                    default:
                        return nil
                    } }() else {
//                        print("Skipping feature - could not get suitable geometry for type!")
                        return nil
                }
                
                let attributes: [String : Any] = [
                    "Key": cluster.clusterKey,
                    "FeatureCount": cluster.itemCount,
                    "ShouldDisplayItems": cluster.itemCount >= minClusterCount ? 0 : -1
                ]
                
                return table.createFeature(attributes: attributes, geometry: geometry)
            })
        }
    }
}

extension AGSGeometryType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .point:
            return "Point"
        case .multipoint:
            return "Multipoint"
        case .polyline:
            return "Polyline"
        case .polygon:
            return "Polygon"
        case .envelope:
            return "Envelope"
        @unknown default:
            fatalError("Unexpected Geometry Type!")
        }
    }
}

fileprivate let defaultCoverageSymbol = AGSSimpleFillSymbol(style: .solid,
                                                            color: UIColor.red.withAlphaComponent(0.3),
                                                            outline: AGSSimpleLineSymbol(style: .solid, color: .brown, width: 2))

fileprivate let smallClusterColor = UIColor(red: 0, green: 0.491, blue: 0, alpha: 1)
fileprivate let mediumClusterColor = UIColor(red: 0.838, green: 0.5, blue: 0, alpha: 1)
fileprivate let largeClusterColor = UIColor(red: 0.615, green: 0.178, blue: 0.550, alpha: 1)

fileprivate let innerSize: CGFloat = 24
fileprivate let borderSize: CGFloat = 6
fileprivate let fontSize: CGFloat = 14

fileprivate func getCentroidSymbol(sizeFactor: CGFloat = 1, color: UIColor = smallClusterColor) -> AGSSymbol {
    let bgSymbol = AGSSimpleMarkerSymbol(style: .circle, color: color, size: (innerSize + borderSize) * sizeFactor)
    let bgSymbol2 = AGSSimpleMarkerSymbol(style: .circle, color: UIColor.white.withAlphaComponent(0.7), size: (innerSize + (borderSize/2)) * sizeFactor)
    let bgSymbol3 = AGSSimpleMarkerSymbol(style: .circle, color: color.withAlphaComponent(0.7), size: innerSize * sizeFactor)
    return AGSCompositeSymbol(symbols: [bgSymbol, bgSymbol2, bgSymbol3])
}
