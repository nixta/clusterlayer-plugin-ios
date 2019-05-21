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

fileprivate let clusterTableFields: [AGSField] = [
    AGSField(fieldType: .int32, name: "Key", alias: "Key", length: 0, domain: nil, editable: true, allowNull: false),
    AGSField(fieldType: .int16, name: "FeatureCount", alias: "Feature Count", length: 0, domain: nil, editable: true, allowNull: false)
]

fileprivate let defaultCoverageSymbol = AGSSimpleFillSymbol(style: .solid,
                                                            color: UIColor.red.withAlphaComponent(0.3),
                                                            outline: AGSSimpleLineSymbol(style: .solid, color: .brown, width: 2))

fileprivate let smallClusterColor = UIColor(red: 0, green: 0.491, blue: 0, alpha: 1)
fileprivate let mediumClusterColor = UIColor(red: 0.838, green: 0.5, blue: 0, alpha: 1)
fileprivate let largeClusterColor = UIColor(red: 0.615, green: 0.178, blue: 0.550, alpha: 1)

fileprivate let innerSize: CGFloat = 24
fileprivate let borderSize: CGFloat = 6
fileprivate let fontSize: CGFloat = 14

fileprivate func getCompositeSymbol(sizeFactor: CGFloat = 1, color: UIColor = smallClusterColor) -> AGSCompositeSymbol {
    let bgSymbol = AGSSimpleMarkerSymbol(style: .circle, color: color, size: (innerSize + borderSize) * sizeFactor)
    let bgSymbol2 = AGSSimpleMarkerSymbol(style: .circle, color: UIColor.white.withAlphaComponent(0.7), size: (innerSize + (borderSize/2)) * sizeFactor)
    let bgSymbol3 = AGSSimpleMarkerSymbol(style: .circle, color: color.withAlphaComponent(0.7), size: innerSize * sizeFactor)
    return AGSCompositeSymbol(symbols: [bgSymbol, bgSymbol2, bgSymbol3])
}

class ClusterLayer<T>: AGSFeatureCollectionLayer where T: AGSGeoElement, T: Hashable {
    
    let manager: LODLevelGriddedClusterManager<T>!
    
    let sourceLayer: AGSFeatureLayer!
    
    var zoomObserver: NSKeyValueObservation!
    
    var currentLOD: Int = 0
    
    var clusterSymbol: AGSSymbol = getCompositeSymbol() {
        didSet {
            clusterPointsTable.renderer = AGSSimpleRenderer(symbol: clusterSymbol)
        }
    }
    var coverageSymbol: AGSSymbol = defaultCoverageSymbol {
        didSet {
            clusterCoveragesTable.renderer = AGSSimpleRenderer(symbol: coverageSymbol)
        }
    }
    
    private var clusterPointsTable: AGSFeatureCollectionTable = {
        let table = AGSFeatureCollectionTable(fields: clusterTableFields,
                                                      geometryType: .point,
                                                      spatialReference: AGSSpatialReference.webMercator())
        let classBreakSmall = AGSClassBreak(description: "Small", label: "Small Cluster",
                                       minValue: 5, maxValue: 50,
                                       symbol: getCompositeSymbol())
        let classBreakMedium = AGSClassBreak(description: "Medium", label: "MEdium Cluster",
                                       minValue: 99, maxValue: 999,
                                       symbol: getCompositeSymbol(sizeFactor: 1.2, color: mediumClusterColor))
        let classBreakLarge = AGSClassBreak(description: "Large", label: "Large Cluster",
                                       minValue: 1000, maxValue: 1E6,
                                       symbol: getCompositeSymbol(sizeFactor: 1.3, color: largeClusterColor))
        table.renderer = AGSClassBreaksRenderer(fieldName: "FeatureCount", classBreaks: [classBreakSmall, classBreakMedium, classBreakLarge])
        return table
    }()
    
    private var clusterCoveragesTable: AGSFeatureCollectionTable = {
        let table = AGSFeatureCollectionTable(fields: clusterTableFields, geometryType: .polygon, spatialReference: AGSSpatialReference.webMercator())
        let classBreak = AGSClassBreak(description: "Clustered", label: "Clustered",
                                       minValue: 5, maxValue: 1E6,
                                       symbol: defaultCoverageSymbol)
        table.renderer = AGSClassBreaksRenderer(fieldName: "FeatureCount", classBreaks: [classBreak])
        return table
    }()
    
    private(set) var clusterPointLayer: AGSFeatureLayer?
    
    private(set) var clusterCoverageLayer: AGSFeatureLayer?
    
    init(mapView: AGSMapView, featureLayer: AGSFeatureLayer) {
        
        manager = LODLevelGriddedClusterManager<T>(mapView: mapView)
        
        sourceLayer = featureLayer

        let tables = [clusterPointsTable, clusterCoveragesTable]
        
        super.init(featureCollection: AGSFeatureCollection(featureCollectionTables: tables))
        
        // We shouldn't have to retrieve these, but there may be a bug in 100.5 Runtime
        clusterPointsTable = featureCollection.tables[0] as! AGSFeatureCollectionTable
        clusterCoveragesTable = featureCollection.tables[1] as! AGSFeatureCollectionTable
        
        clusterPointLayer = layers[0]
        clusterCoverageLayer = layers[1]
        
        let textSymbol = AGSTextSymbol(text: "", color: .white, size: fontSize, horizontalAlignment: .center, verticalAlignment: .middle)
        if let ld = try? AGSLabelDefinition.with(fieldName: "FeatureCount", textSymbol: textSymbol) {
            clusterPointLayer?.labelDefinitions.add(ld)
            clusterPointLayer?.labelsEnabled = true
        }
        
        let initializationGroup = DispatchGroup()
        initializationGroup.enter()
        
        let sourceParams = AGSQueryParameters()
        sourceParams.whereClause = "1=1"
        
        sourceLayer.featureTable?.queryFeatures(with: sourceParams, completion: { [weak self] (sourceFeatureResults, error) in
            defer { initializationGroup.leave() }
            
            if let error = error {
                print("Error querying source features: \(error.localizedDescription)")
                return
            }
            
            guard let self = self, let sourceFeatures = sourceFeatureResults?.featureEnumerator().allObjects as? [T] else { return }

            self.manager.add(items: sourceFeatures)
        })
        
        initializationGroup.enter()
        AGSLoadObjects(tables) { (_) in
            for errorTable in tables.filter({ $0.loadError != nil }) {
                print("Error loading table '\(errorTable.tableName)': \(errorTable.loadError!)")
            }
            initializationGroup.leave()
        }
        
        initializationGroup.notify(queue: .main) { [weak self] in
            
            guard let self = self else { return }
            
            guard let clusterProviderForScale = self.manager.clusterProvider(for: mapView.mapScale) else {
                print("Unable to set initial cluster LOD")
                return
            }
            
            self.updateDisplayForProvider(provider: clusterProviderForScale)
            
            self.zoomObserver = mapView.observe(\.isNavigating, options: [.initial, .new]) { [weak self] (changedMapView, change) in
                guard change.newValue == false else { return }
                
                guard let self = self else { return }
                
                guard let clusterProviderForScale = self.manager.clusterProvider(for: changedMapView.mapScale),
                    clusterProviderForScale.lod.level != self.currentLOD else { return }
                
                self.updateDisplayForProvider(provider: clusterProviderForScale)
            }

        }
        
    }
    
    func updateDisplayForProvider(provider: LODLevelGriddedClusterProvider<T>) {

        self.currentLOD = provider.lod.level
        
        var pendingCount = 0
        for cluster in provider.clusters {
            pendingCount += cluster.flushPending()
        }
        
        updateClusterDisplayWithProvider(display: .clusterPoints, provider: provider)

//        if let layer = clusterCoverageLayer, let table = layer.featureTable {
//            self.updateTablesWithGrid(table: table, gridForScale: gridForScale)
//        }
        
//        print("Flushed \(pendingCount) pending items on \(provider.clusters.count) clusters")
    }
    
    private enum ClusterDisplay {
        case clusterPoints
        case clusterCoverages
    }
    
    private func updateClusterDisplayWithProvider(display: ClusterDisplay, provider: LODLevelGriddedClusterProvider<T>) {
        
        let table: AGSFeatureCollectionTable = {
            switch display {
            case .clusterPoints:
                return clusterPointsTable
            case .clusterCoverages:
                return clusterCoveragesTable
            }
        }()
        
        // Get currently displayed clusters
        let params = AGSQueryParameters.queryForAll()
        table.queryFeatures(with: params, completion: { (result, error) in
            if let error = error {
                print("Error querying features to delete \(error.localizedDescription)")
                return
            }
            
            // Get all the clusters to remove from display.
            guard let featuresToDelete = result?.featureEnumerator().allObjects else { return }
            
            let addRemoveGroup = DispatchGroup()
            addRemoveGroup.enter()
            addRemoveGroup.enter()
            
            // Remove previous LOD's clusters from display.
            table.delete(featuresToDelete, completion: { (error) in
                addRemoveGroup.leave()
                if let error = error {
                    print("Error deleting features: \(error.localizedDescription)")
                    return
                }
            })
            
            // Add new LOD's clusters to display.
            let featuresToAdd = provider.clusters.asFeatures(in: table)
            table.add(featuresToAdd, completion: { error in
                addRemoveGroup.leave()
                if let error = error {
                    print("Error adding features for new map scale: \(error.localizedDescription)")
                    return
                }
            })
            
            addRemoveGroup.notify(queue: .main) {
                print("Just removed \(featuresToDelete.count) and added \(featuresToAdd.count) features as \(table.geometryType)s")
            }
        })
        
    }
    
    deinit {
        zoomObserver.invalidate()
        zoomObserver = nil
    }
}

extension Set where Element: Cluster {
    func asFeatures(in table: AGSFeatureTable) -> [AGSFeature] {
        return self.compactMap({ (cluster) -> AGSFeature? in
            guard let geometry: AGSGeometry? = {
                switch table.geometryType {
                case .point:
                    return cluster.centroid
                case .polygon:
                    return cluster.coverage
                default:
                    return nil
                } }() else {
                    print("Skipping feature - could not get suitable geometry for type!")
                    return nil
            }
            
            let attributes: [String : Any] = [
                "Key": cluster.clusterKey,
                "FeatureCount": cluster.itemCount
            ]
            
            return table.createFeature(attributes: attributes, geometry: geometry)
        })
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
