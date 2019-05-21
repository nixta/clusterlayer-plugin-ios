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

class GeoElementCluster<T>: Cluster where T: AGSGeoElement, T: Hashable {

    let clusterKey: Int = getNextClusterKey()
    var items = Set<T>()
    var itemCount: Int { return items.count }

    internal unowned var containingCell: LODLevelGriddedClusterGridCell<T>!

    
    private var pendingAdds: Set<T>?
    
    private var isCentroidDirty = true
    private var cachedCentroid: AGSPoint?
    private var isCoverageDirty = true
    private var cachedCoverage: AGSPolygon?
    private var isExtentDirty = true
    private var cachedExtent: AGSEnvelope?
    
}

extension GeoElementCluster {
    
    var centroid: AGSPoint? {
        if isCentroidDirty {
            cachedCentroid = calculateCentroid(features: items)
            isCentroidDirty = false
        }
        
        return cachedCentroid
    }
    
    var coverage: AGSPolygon? {
        if isCoverageDirty {
            let featureGeometries = items.compactMap({ $0.geometry as? AGSPoint })
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
    
    var extent: AGSEnvelope? {
        if isCentroidDirty {
            cachedExtent = AGSGeometryEngine.unionGeometries(items.compactMap({ $0.geometry }))?.extent
            isExtentDirty = false
        }
        
        return cachedExtent
    }
    
    func dirtyAllGeometries() {
        isCentroidDirty = true
        isCoverageDirty = true
        isExtentDirty = true
    }
}

extension GeoElementCluster {
    
    func add(feature: T) {
        items.insert(feature)
        
        dirtyAllGeometries()
    }
    
    func remove(feature: T) {
        items.remove(feature)
        
        dirtyAllGeometries()
    }
    
    func add<S: Sequence>(features: S) where S.Element == T {
        self.items.formUnion(features)
        
        dirtyAllGeometries()
    }

    func addPending(feature: T) {
        if pendingAdds == nil {
            pendingAdds = Set<T>()
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

extension GeoElementCluster: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(clusterKey)
    }

    static func == (lhs: GeoElementCluster, rhs: GeoElementCluster) -> Bool {
        return lhs.clusterKey == rhs.clusterKey
    }

}

class LODLevelGeoElementCluster<T>: GeoElementCluster<T>, LODLevelCluster where T: AGSGeoElement, T: Hashable {
    var childClusters = Set<LODLevelGeoElementCluster<T>>()
    private weak var parentCluster: LODLevelGeoElementCluster<T>?
    
    func add(childCluster: LODLevelGeoElementCluster<T>) {
        childCluster.parentCluster = self
        
        childClusters.insert(childCluster)
        items.formUnion(childCluster.items)
        
        dirtyAllGeometries()
    }
    
    func remove(childCluster: LODLevelGeoElementCluster<T>) {
        childCluster.parentCluster = nil
        
        childClusters.remove(childCluster)
        items.subtract(childCluster.items)
        
        dirtyAllGeometries()
    }
}
