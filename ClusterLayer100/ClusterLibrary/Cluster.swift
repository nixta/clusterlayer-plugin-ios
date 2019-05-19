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
    let clusterKey: Int = getNextClusterKey()
    
    var features = Set<AGSFeature>()
    
    var childClusters = Set<Cluster>()
    
    internal unowned var containingCell: ZoomClusterGridCell!
    private weak var parentCluster: Cluster?

    private var grid: ClusterProvider {
        return containingCell.grid
    }

    var featureCount: Int {
        return features.count
    }
    
    private var pendingAdds: Set<AGSFeature>?
    

    
    
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

    
    var coverageGraphic: AGSGraphic { fatalError("NOT IMPLEMENTED") }
}

extension Cluster {
    
    func add(childCluster: Cluster) {
        childCluster.parentCluster = self
        
        childClusters.insert(childCluster)
        features.formUnion(childCluster.features)
        
        isGeometryDirty = true
    }
    
    func add(feature: AGSFeature) {
        features.insert(feature)
        
        isGeometryDirty = true
    }
    
    func remove(childCluster: Cluster) {
        childCluster.parentCluster = nil
        
        childClusters.remove(childCluster)
        features.subtract(childCluster.features)
        
        isGeometryDirty = true
    }
    
    func remove(feature: AGSFeature) {
        features.remove(feature)
        
        isGeometryDirty = true
    }
    
    func add<T: Sequence>(features: T) where T.Element == AGSFeature {
        self.features.formUnion(features)
        
        isGeometryDirty = true
    }

    func addPending(feature: AGSFeature) {
        if pendingAdds == nil {
            pendingAdds = Set<AGSFeature>()
        }
        pendingAdds?.insert(feature)
    }
    
    func flushPending() {
        guard let pending = pendingAdds else { return }
        
        self.add(features: pending)
        
        pendingAdds?.removeAll()
        pendingAdds = nil
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
