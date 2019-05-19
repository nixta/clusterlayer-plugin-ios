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

private var nextClusterKey: Int = 0
private func getNextClusterKey() -> Int {
    defer { nextClusterKey += 1 }
    return nextClusterKey
}

class Cluster {
    private var grid: ClusterProvider {
        return containingCell.grid
    }
    private unowned var containingCell: ZoomClusterGridCell!
    private weak var parentCluster: Cluster?
    
    var features: [AGSFeature] = []

    var featureCount: Int {
        return features.count
    }
    
    let clusterKey: Int = getNextClusterKey()
    
    var childClusters = Set<Cluster>()

    
    
    var showCoverage: Bool = false

    private var isGeometryDirty = true
    
    
    private var cachedCentroid: AGSPoint?
    private var cachedCoverage: AGSGeometry?
    private var cachedExtent: AGSEnvelope?
    
    var centroid: AGSPoint? {
        if isGeometryDirty {
            cachedCentroid = calculateCentroid(features: features)
        }
        
        return cachedCentroid
    }
    var coverage: AGSPolygon? { fatalError("NOT IMPLEMENTED") }
    var envelope: AGSEnvelope? { fatalError("NOT IMPLEMENTED") }

    init() {
    }
    
    
    func calculateCentroid(features: [AGSFeature]) -> AGSPoint {
        let points = features.compactMap { (feature) -> AGSPoint? in
            if let pt = feature.geometry as? AGSPoint {
                return pt
            } else {
                return feature.geometry?.extent.center
            }
        }
        
        guard points.count > 0 else {
            assertionFailure("Attempting to get centroid for empty cluster!")
            return containingCell.center
        }
        
        if points.count == 1 {
            return points.first!
        }
        
        var totalX: Double = 0
        var totalY: Double = 0
        var count = 0
        
        var sr: AGSSpatialReference?
        for feature in features {
            guard let featurePoint = feature.geometry as? AGSPoint else { continue }

            if sr == nil { sr = featurePoint.spatialReference }
            
            totalX += featurePoint.x
            totalY += featurePoint.y
            count += 1
        }
        
        return AGSPoint(x: totalX/Double(count), y: totalY/Double(count), spatialReference: sr)
    }
    
    
    var coverageGraphic: AGSGraphic { fatalError("NOT IMPLEMENTED") }

    func add(child: Cluster) {
        child.parentCluster = self
        
        childClusters.insert(child)
        features.append(contentsOf: child.features)
        
        isGeometryDirty = true
    }
    
    func add(feature: AGSFeature) {
        features.append(feature)
        
        isGeometryDirty = true
    }
    
    func remove(childCluster: Cluster) {
        childCluster.parentCluster = nil
        
        childClusters.remove(childCluster)
        features.removeAll { childCluster.features.contains($0) }
        
        isGeometryDirty = true
    }
    
    func remove(feature: AGSFeature) {
        features.removeAll { $0 == feature }
        
        isGeometryDirty = true
    }
    
    func add(geoElements: Array<AGSGeoElement>) {
        for element in geoElements {
            
        }
    }

}

extension AGSFeature {
    private struct ClusterAssociatedKeys {
        static var ClusterKey = "agscl_Cluster"
    }
    
    var isCluster: Bool {
        return self.cluster != nil
    }
    
    var cluster: Cluster? {
        get {
            return objc_getAssociatedObject(self, &ClusterAssociatedKeys.ClusterKey) as? Cluster
        }
    }
}

extension Cluster {
    static func clusterForPoint(mapPoint: AGSPoint) -> Cluster {
        fatalError("NOT IMPLEMENTED")
    }
    
}

extension Cluster: Hashable {
    static func == (lhs: Cluster, rhs: Cluster) -> Bool {
        return lhs.clusterKey == rhs.clusterKey
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(clusterKey)
    }
}
