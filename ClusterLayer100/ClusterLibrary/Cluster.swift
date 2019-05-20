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

    private var isCentroidDirty = true
    private var cachedCentroid: AGSPoint?
    private var isCoverageDirty = true
    private var cachedCoverage: AGSPolygon?
    private var isExtentDirty = true
    private var cachedExtent: AGSEnvelope?
    
    var centroid: AGSPoint? {
        if isCentroidDirty {
            cachedCentroid = calculateCentroid(features: features)
            isCentroidDirty = false
        }
        
        return cachedCentroid
    }
    
    var coverage: AGSPolygon? {
        if isCoverageDirty {
            let featureGeometries = features.compactMap({ $0.geometry as? AGSPoint })
            if featureGeometries.count == 1, let geom = featureGeometries.first {
                cachedCoverage = AGSGeometryEngine.bufferGeometry(geom, byDistance: 20)
            } else if featureGeometries.count == 2 {
                let line = AGSPolyline(points: featureGeometries)
                cachedCoverage = AGSGeometryEngine.bufferGeometry(line, byDistance: 20)
            } else {
                cachedCoverage = AGSGeometryEngine.convexHull(forGeometries: featureGeometries, mergeInputs: true)?.first as? AGSPolygon
            }
            isCoverageDirty = false
        }
        return cachedCoverage
    }
    
    var envelope: AGSEnvelope? {
        if isCentroidDirty {
            cachedExtent = AGSGeometryEngine.unionGeometries(features.compactMap({ $0.geometry }))?.extent
            isExtentDirty = false
        }
        
        return cachedExtent
    }
    
    func dirtyAllGeometries() {
        isCentroidDirty = true
        isCoverageDirty = true
        isExtentDirty = true
    }

    
    var coverageGraphic: AGSGraphic { fatalError("NOT IMPLEMENTED") }
}

extension Cluster {
    
    func add(childCluster: Cluster) {
        childCluster.parentCluster = self
        
        childClusters.insert(childCluster)
        features.formUnion(childCluster.features)
        
        dirtyAllGeometries()
    }
    
    func add(feature: AGSFeature) {
        features.insert(feature)
        
        dirtyAllGeometries()
    }
    
    func remove(childCluster: Cluster) {
        childCluster.parentCluster = nil
        
        childClusters.remove(childCluster)
        features.subtract(childCluster.features)
        
        dirtyAllGeometries()
    }
    
    func remove(feature: AGSFeature) {
        features.remove(feature)
        
        dirtyAllGeometries()
    }
    
    func add<T: Sequence>(features: T) where T.Element == AGSFeature {
        self.features.formUnion(features)
        
        dirtyAllGeometries()
    }

    func addPending(feature: AGSFeature) {
        if pendingAdds == nil {
            pendingAdds = Set<AGSFeature>()
        }
        pendingAdds?.insert(feature)
    }
    
    func flushPending() -> Int {
        guard let pending = pendingAdds else { return 0 }
        
        self.add(features: pending)
        
        let pendingCount = pending.count
        
        pendingAdds?.removeAll()
        pendingAdds = nil
        
        return pendingCount
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
