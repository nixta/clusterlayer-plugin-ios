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

class ClusterLayer: AGSFeatureCollectionLayer {
    
    let manager: ZoomClusterGridManager!
    
    let sourceLayer: AGSFeatureLayer!
    
    var zoomObserver: NSKeyValueObservation!
    
    var currentLOD: Int = 0
    
    private var clusterPointLayer: AGSFeatureLayer?
    private var clusterCoverageLayer: AGSFeatureLayer?
    
    init(mapView: AGSMapView, featureLayer: AGSFeatureLayer) {
        
        sourceLayer = featureLayer

        let fields: [AGSField] = [
            AGSField(fieldType: .int32, name: "Key", alias: "Key", length: 0, domain: nil, editable: true, allowNull: false),
            AGSField(fieldType: .int16, name: "FeatureCount", alias: "Feature Count", length: 0, domain: nil, editable: true, allowNull: false)
        ]
        
        let clustersTable = AGSFeatureCollectionTable(fields: fields, geometryType: .point, spatialReference: AGSSpatialReference.webMercator())
        let clusteredClass = AGSClassBreak(description: "Clustered", label: "Clustered", minValue: 0, maxValue: 1E6, symbol: AGSSimpleMarkerSymbol(style: .circle, color: .red, size: 25))
        let renderer = AGSClassBreaksRenderer(fieldName: "FeatureCount", classBreaks: [clusteredClass])
        clustersTable.renderer = renderer
        
        let coveragesTable = AGSFeatureCollectionTable(fields: fields, geometryType: .polygon, spatialReference: AGSSpatialReference.webMercator())
        let clusteredClass2 = AGSClassBreak(description: "Clustered", label: "Clustered", minValue: 0, maxValue: 1E6,
                                            symbol: AGSSimpleFillSymbol(style: .solid, color: UIColor.red.withAlphaComponent(0.3),
                                                                        outline: AGSSimpleLineSymbol(style: .solid, color: .brown, width: 2)))
        coveragesTable.renderer = AGSClassBreaksRenderer(fieldName: "FeatureCount", classBreaks: [clusteredClass2])

        let fc = AGSFeatureCollection(featureCollectionTables: [clustersTable, coveragesTable])
        
        manager = ZoomClusterGridManager(mapView: mapView)
        
        super.init(featureCollection: fc)
        
        clusterPointLayer = layers.first
        clusterCoverageLayer = layers.last
        
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
            
            guard let self = self, let sourceFeatures = sourceFeatureResults?.featureEnumerator().allObjects else { return }
            
            self.manager.addFeatures(features: sourceFeatures)
        })
        
        initializationGroup.enter()
        AGSLoadObjects(fc.tables as! [AGSFeatureTable]) { (_) in
            initializationGroup.leave()
        }
        
        initializationGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            guard let gridForScale = self.manager.gridForScale(mapScale: mapView.mapScale) else {
                print("Unable to set initial cluster LOD")
                return
            }
            
            self.setToGrid(grid: gridForScale)
        }
        
        zoomObserver = mapView.observe(\.isNavigating) { [weak self] (changedMapView, _) in
            guard changedMapView.isNavigating == false else { return }
            
            guard let self = self else { return }
            
            guard let gridForScale = self.manager.gridForScale(mapScale: changedMapView.mapScale),
                gridForScale.lod.level != self.currentLOD else { return }
            
            self.setToGrid(grid: gridForScale)
        }
    }
    
    func setToGrid(grid: ZoomClusterGrid) {
        print("newLOD = \(grid.lod.level), oldLOD = \(self.currentLOD)")
        
        self.currentLOD = grid.lod.level
        
        var pendingCount = 0
        for cluster in grid.clusters {
            pendingCount += cluster.flushPending()
        }
        
        if let layer = clusterPointLayer, let table = layer.featureTable {
            self.updateTablesWithGrid(table: table, gridForScale: grid)
        }
//        if let layer = clusterCoverageLayer, let table = layer.featureTable {
//            self.updateTablesWithGrid(table: table, gridForScale: gridForScale)
//        }
        
        print("Flushed \(pendingCount) pending items on \(grid.clusters.count) clusters")
    }
    
    func updateTablesWithGrid(table: AGSFeatureTable, gridForScale: ZoomClusterGrid) {
        let params = AGSQueryParameters()
        params.whereClause = "1=1"
        table.queryFeatures(with: params, completion: { [table] (result, error) in
            if let error = error {
                print("Error querying features to delete \(error.localizedDescription)")
                return
            }
            
            guard let featuresToDelete = result?.featureEnumerator().allObjects else { return }
            
            let addRemoveGroup = DispatchGroup()
            addRemoveGroup.enter()
            addRemoveGroup.enter()
            
            // Remove previous LOD's clusters from display
            table.delete(featuresToDelete, completion: { (error) in
                addRemoveGroup.leave()
                if let error = error {
                    print("Error deleting features: \(error.localizedDescription)")
                    return
                }
            })
            
            // Add new LOD's clusters to display.
            let featuresToAdd = gridForScale.clusters.compactMap({ (cluster) -> AGSFeature? in
                guard let geometry: AGSGeometry? = {
                    switch table.geometryType {
                    case .point:
                        return cluster.centroid
                    case .polygon:
                        return cluster.coverage
                    default:
                        return nil
                    }
                    }() else {
                    print("Skipping feature - could not get suitable geometry for type!")
                    return nil
                }

                let attributes = [
                    "Key": cluster.clusterKey,
                    "FeatureCount": cluster.featureCount
                ]

                let featureForCluster = table.createFeature(attributes: attributes, geometry: geometry)

                return featureForCluster
            })
            
            table.add(featuresToAdd, completion: { error in
                addRemoveGroup.leave()
                if let error = error {
                    print("Error adding features for new map scale: \(error.localizedDescription)")
                    return
                }
            })
            
            addRemoveGroup.notify(queue: .main) {
                print("Just removed \(featuresToDelete.count) and added \(featuresToAdd.count) features as \(table.geometryType)")
            }
        })
    }
    
    deinit {
        zoomObserver.invalidate()
        zoomObserver = nil
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
        }
    }
}
