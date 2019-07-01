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

internal enum ClusterLayerComponent: CustomStringConvertible {
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

class ClusterLayer<M: ClusterManager>: AGSFeatureCollectionLayer {
    
    typealias T = M.ItemType
    
    let manager: M!
    
    let sourceLayer: AGSFeatureLayer!
    
    let minClusterCount: Int = 3
    
    private var currentClusterProvider: M.ClusterProviderType?

    var showCoverages: Bool = false {
        didSet {
            // Bug in 100.5 means we can't just change the sublayer visibility.
            // coveragesLayer?.isVisible = showCoverages

            // Instead, we'll use the somewhat more cumbersome approach of removing
            // or populating the coverages in the coverages table.
            updateClusterDisplay(component: .coverages)
        }
    }
    
    // MARK: Symbols
    var clusterSymbol: AGSSymbol = getClusterSymbol() {
        didSet {
            clustersTable.renderer = AGSSimpleRenderer(symbol: clusterSymbol)
        }
    }
    var coverageSymbol: AGSSymbol = defaultCoverageSymbol {
        didSet {
            coveragesTable.renderer = AGSSimpleRenderer(symbol: coverageSymbol)
        }
    }
    var clusterLabelTextSymbol = defaultClusterTextSymbol {
        didSet {
            setClusterLabelDefinitions()
        }
    }
    
    // MARK: Sublayers
    private(set) var clustersLayer: AGSFeatureLayer?
    private(set) var coveragesLayer: AGSFeatureLayer?
    private(set) var unclusteredItemsLayer: AGSFeatureLayer?
    
    // MARK: Tables
    private let clustersTable: AGSFeatureCollectionTable = {
        let table = AGSFeatureCollectionTable(fields: clusterTableFields,
                                                      geometryType: .point,
                                                      spatialReference: AGSSpatialReference.webMercator())
        table.displayName = "Clusters"
        let classBreakSmall = AGSClassBreak(description: "Small", label: "Small Cluster",
                                       minValue: 0, maxValue: 100,
                                       symbol: getClusterSymbol())
        let classBreakMedium = AGSClassBreak(description: "Medium", label: "Medium Cluster",
                                       minValue: 100, maxValue: 1000,
                                       symbol: getClusterSymbol(sizeFactor: 1.2, color: mediumClusterColor))
        let classBreakLarge = AGSClassBreak(description: "Large", label: "Large Cluster",
                                       minValue: 1000, maxValue: 1E6,
                                       symbol: getClusterSymbol(sizeFactor: 1.3, color: largeClusterColor))
        table.renderer = AGSClassBreaksRenderer(fieldName: "FeatureCount", classBreaks: [classBreakSmall, classBreakMedium, classBreakLarge])
        return table
    }()
    
    private let coveragesTable: AGSFeatureCollectionTable = {
        let table = AGSFeatureCollectionTable(fields: clusterTableFields, geometryType: .polygon, spatialReference: AGSSpatialReference.webMercator())
        table.displayName = "Coverages"
        let classBreak = AGSClassBreak(description: "Clustered", label: "Clustered",
                                       minValue: 5, maxValue: 1E6,
                                       symbol: defaultCoverageSymbol)
        table.renderer = AGSClassBreaksRenderer(fieldName: "FeatureCount", classBreaks: [classBreak])
        return table
    }()
    
    private let unclusteredItemsTable: AGSFeatureCollectionTable
    
    // MARK: Internals
    private var mapScaleObserver: NSKeyValueObservation!
    
    
    
    // MARK: Initializer
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
        
        // Create a manager
        manager = M(mapView: mapView)
        
        // Store the source layer (we will get data from here)
        sourceLayer = featureLayer
        
        // Create a table for displaying items when they are not clustered. This will reflect the source layer.
        unclusteredItemsTable = AGSFeatureCollectionTable(featureTable: sourceTable)
        unclusteredItemsTable.displayName = "Unclustered Items"
        
        let tables = [unclusteredItemsTable, coveragesTable, clustersTable]
        
        super.init(featureCollection: AGSFeatureCollection(featureCollectionTables: tables))
        
        // Get the layers that were created from the source tables.
        unclusteredItemsLayer = layers[0]
        coveragesLayer = layers[1]
        clustersLayer = layers[2]
        
        // Apply label definition on the clusters layer
        setClusterLabelDefinitions()
        
        setup()
    }
    

    
    
    // MARK: Ready for use
    private func setup() {
        let loadCoordinator = DispatchGroup(2)
        
        var loadErrors: [Error] = []
        let queue = DispatchQueue.global(qos: .userInteractive)

        // At present, AGSFeatureCollectionLayer is loaded upon init().
        // This will future-proof us in case that ever changes.
        super.load { (error) in
            defer { loadCoordinator.leave() }
            if let error = error {
                queue.sync {
                    loadErrors.append(error)
                }
            }
        }
        
        // Most likely this will be loaded already, but if not, we can
        // handle that eventuality.
        sourceLayer.load { [weak self] (error) in
            defer { loadCoordinator.leave() }
            if let error = error {
                queue.sync {
                    loadErrors.append(error)
                }
            }
        }
        
        loadCoordinator.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // If we have more than one load error, we should report it
            guard loadErrors.count == 0 else {
                print("Error(s) while loading ClusterLayer:")
                loadErrors.forEach({ error in
                    print("\(error)")
                })
                return
            }
            
            // Make sure we render unclustered items as if they were in the original layer.
            self.unclusteredItemsTable.renderer = self.sourceLayer.renderer?.copy() as? AGSRenderer
            
            // Reflect the source layer's visible scale range
            self.minScale = self.sourceLayer.minScale
            self.maxScale = self.sourceLayer.maxScale
            
            // Initialize the layer
            let initializationGroup = DispatchGroup(1)
            
            // TODO: Implement paging for services with a result count limit
            self.sourceLayer.featureTable?.queryFeatures(with: AGSQueryParameters.all(), completion: { [weak self] (sourceFeatureResults, error) in
                defer { initializationGroup.leave() }
                
                if let error = error {
                    print("Error querying source features: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self, let sourceFeatures = sourceFeatureResults?.featureEnumerator().allObjects as? [T] else { return }
                
                self.manager.add(items: sourceFeatures)
            })
            
            initializationGroup.notify(queue: .global(qos: .userInitiated)) { [weak self] in
                guard let self = self else { return }
                
                self.updateDisplayForCurrentScale()
                
                self.mapScaleObserver = self.manager.mapView?.observe(\.mapScale, options: [.new], changeHandler: { [weak self] (changedMapView, change) in
                    // AGSMapView emits many mapScale changes, especially on a device.
                    // We want to wait until the map isn't changing any more…
                    DispatchQueue.main.debounce(interval: 0.2, context: changedMapView, action: {
                        guard let self = self else { return }
                        
                        self.updateDisplayForCurrentScale()
                    })
                })
            }

        }
    }
    
    func updateDisplayForCurrentScale() {
        guard let mapView = manager.mapView else {
            preconditionFailure("Cluster Layer updating without a map view!")
        }
        
        guard (minScale == 0 && maxScale == 0) || (minScale < mapView.mapScale && maxScale > mapView.mapScale) else {
            print("Map Scale out of visible range: \(minScale) < \(mapView.mapScale) < \(maxScale)")
            return
        }
        
        guard let clusterProviderForScale = self.manager.clusterProvider(for: mapView.mapScale),
            clusterProviderForScale != self.currentClusterProvider else {
                print("Cluster Provider is unchanged after map navigation (Map Scale \(mapView.mapScale))")
                return
        }
        
        self.currentClusterProvider = clusterProviderForScale
        
        self.updateDisplay()
    }
    
    func updateDisplay() {

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard let _ = self.manager.mapView else { return } // No sense doing any work if there's no map view.
            
            self.currentClusterProvider?.ensureClustersReadyForDisplay()
            
            self.updateClusterDisplay(component: .clusters)
            self.updateClusterDisplay(component: .items)
            self.updateClusterDisplay(component: .coverages)
        }

    }
    
    private func updateClusterDisplay(component: ClusterLayerComponent) {

        let table: AGSFeatureCollectionTable = {
            switch component {
            case .clusters:
                return clustersTable
            case .coverages:
                return coveragesTable
            case .items:
                return unclusteredItemsTable
            }
        }()
        
        // Get currently displayed clusters
        let params = AGSQueryParameters.all()
        table.queryFeatures(with: params, completion: { [weak self] (result, error) in
            if let error = error {
                print("Error querying features to delete \(error.localizedDescription)")
                return
            }
            
            guard let self = self else { return }
            
            // Get all the clusters to remove from display.
            guard let featuresToRemove = result?.featureEnumerator().allObjects else { return }
            let featuresToAdd: [AGSFeature]? = {
                switch component {
                case .coverages:
                    if !self.showCoverages {
                        return nil
                    }
                    fallthrough
                default:
                    return self.currentClusterProvider?.clusters.asFeatures(in: table, for: component, minClusterCount: self.minClusterCount)
                }
            }()

            let addRemoveGroup = DispatchGroup(2)
            
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
                print("Removed \(featuresToRemove.count) and added \(featuresToAdd?.count ?? 0) \(component) for provider '\(self.currentClusterProvider?.name ?? "None")'")
            }
        })

    }

    func setClusterLabelDefinitions() {
        clustersLayer?.labelDefinitions.removeAllObjects()
        if let ld = try? AGSLabelDefinition.with(fieldName: "FeatureCount", textSymbol: clusterLabelTextSymbol) {
            clustersLayer?.labelDefinitions.add(ld)
            clustersLayer?.labelsEnabled = true
        } else {
            clustersLayer?.labelsEnabled = false
        }
    }
    
    deinit {
        mapScaleObserver.invalidate()
        mapScaleObserver = nil
    }
}

fileprivate let clusterTableFields: [AGSField] = [
    AGSField(fieldType: .int32, name: "Key", alias: "Key", length: 0, domain: nil, editable: true, allowNull: false),
    AGSField(fieldType: .int16, name: "FeatureCount", alias: "Feature Count", length: 0, domain: nil, editable: true, allowNull: false),
    AGSField(fieldType: .int16, name: "ShouldDisplayItems", alias: "Display Exploded", length: 0, domain: nil, editable: true, allowNull: false)
]

fileprivate let defaultCoverageSymbol = AGSSimpleFillSymbol(style: .solid,
                                                            color: UIColor.red.withAlphaComponent(0.3),
                                                            outline: AGSSimpleLineSymbol(style: .solid, color: .brown, width: 2))
fileprivate let defaultClusterTextSymbol = AGSTextSymbol(text: "", color: .white, size: fontSize,
                                                         horizontalAlignment: .center,
                                                         verticalAlignment: .middle)

fileprivate let smallClusterColor = UIColor(red: 0, green: 0.491, blue: 0, alpha: 1)
fileprivate let mediumClusterColor = UIColor(red: 0.838, green: 0.5, blue: 0, alpha: 1)
fileprivate let largeClusterColor = UIColor(red: 0.615, green: 0.178, blue: 0.550, alpha: 1)

fileprivate let innerSize: CGFloat = 24
fileprivate let borderSize: CGFloat = 6
fileprivate let fontSize: CGFloat = 14

fileprivate func getClusterSymbol(sizeFactor: CGFloat = 1, color: UIColor = smallClusterColor) -> AGSSymbol {
    let bgSymbol = AGSSimpleMarkerSymbol(style: .circle, color: color, size: (innerSize + borderSize) * sizeFactor)
    let bgSymbol2 = AGSSimpleMarkerSymbol(style: .circle, color: UIColor.white.withAlphaComponent(0.7), size: (innerSize + (borderSize/2)) * sizeFactor)
    let bgSymbol3 = AGSSimpleMarkerSymbol(style: .circle, color: color.withAlphaComponent(0.7), size: innerSize * sizeFactor)
    return AGSCompositeSymbol(symbols: [bgSymbol, bgSymbol2, bgSymbol3])
}
