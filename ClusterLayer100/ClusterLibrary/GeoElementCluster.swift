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

typealias ClusterableGeoElement = AGSGeoElement & Hashable

class GeoElementCluster<T: ClusterableGeoElement>: Cluster {

    let clusterKey: Int = getNextClusterKey()
    var items = Set<T>()
    var itemCount: Int { return items.count }

    private var pendingAdds = Set<T>()
    
    private var isCentroidDirty = true
    private var cachedCentroid: AGSPoint?
    private var isCoverageDirty = true
    private var cachedCoverage: AGSPolygon?
    private var isExtentDirty = true
    private var cachedExtent: AGSEnvelope?
    

    // MARK: Cluster Geometries
    var centroid: AGSPoint? {
        if isCentroidDirty {
            cachedCentroid = calculateCentroid(features: items)
            isCentroidDirty = false
        }
        
        return cachedCentroid
    }
    
    var coverage: AGSPolygon? {
        if isCoverageDirty {
            cachedCoverage = calculateCoverage(features: items)
            isCoverageDirty = false
        }
        return cachedCoverage
    }
    
    var extent: AGSEnvelope? {
        if isCentroidDirty {
            cachedExtent = calculateExtent(features: items)
            isExtentDirty = false
        }
        
        return cachedExtent
    }
    
    internal func invalidateAllGeometries() {
        isCentroidDirty = true
        isCoverageDirty = true
        isExtentDirty = true
    }

    
    // MARK: Cluster Content
    func add(item: T) {
        items.insert(item)
        
        invalidateAllGeometries()
    }
    
    func remove(item: T) {
        items.remove(item)
        
        invalidateAllGeometries()
    }
    
    func add<S: Sequence>(items: S) where S.Element == T {
        self.items.formUnion(items)
        
        invalidateAllGeometries()
    }
    
    func removeAllItems() {
        self.items.removeAll()
        
        invalidateAllGeometries()
    }
    
}

extension GeoElementCluster {
    
    func addPending(item: T) {
        pendingAdds.insert(item)
        
        invalidateAllGeometries()
    }
    
    @discardableResult func flushPendingItemsIntoCluster() -> Int {
        guard pendingAdds.count > 0 else { return 0 }
        
        self.add(items: pendingAdds)
        
        let pendingCount = pendingAdds.count
        
        pendingAdds.removeAll()
        
        return pendingCount
    }

}

extension GeoElementCluster {
    
    func calculateCentroid<S: Sequence>(features: S) -> AGSPoint? where S.Element == T {
        flushPendingItemsIntoCluster()
        
        let points = features.compactMap { (feature) -> AGSPoint? in
            if let pt = feature.geometry as? AGSPoint {
                return pt
            } else {
                return feature.geometry?.extent.center
            }
        }
        
        guard points.count > 0 else {
            assertionFailure("Attempting to get centroid for empty cluster!")
            return nil
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
    
    func calculateCoverage<S: Sequence>(features: S) -> AGSPolygon? where S.Element == T {
        flushPendingItemsIntoCluster()

        let featureGeometries = items.compactMap({ $0.geometry as? AGSPoint })
        if featureGeometries.count == 1, let geom = featureGeometries.first {
            return AGSGeometryEngine.bufferGeometry(geom, byDistance: 20)
        } else if featureGeometries.count == 2 {
            let line = AGSPolyline(points: featureGeometries)
            return AGSGeometryEngine.bufferGeometry(line, byDistance: 20)
        } else {
            return AGSGeometryEngine.convexHull(forGeometries: featureGeometries, mergeInputs: true)?.first as? AGSPolygon
        }
    }
    
    func calculateExtent<S: Sequence>(features: S) -> AGSEnvelope? where S.Element == T {
        flushPendingItemsIntoCluster()

        return AGSGeometryEngine.unionGeometries(features.compactMap({ $0.geometry }))?.extent
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
