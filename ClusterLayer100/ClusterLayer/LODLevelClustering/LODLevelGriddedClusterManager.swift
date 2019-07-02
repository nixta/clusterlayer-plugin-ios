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

class LODLevelGriddedClusterManager<T: ClusterableGeoElement>: ClusterManager {
    

    /// A dictionary of grid cluster providers, keyed by LOD level.
    var clusterProviders: [Int : LODLevelGriddedClusterProvider<T>] = [:]
    
    weak var mapView: AGSMapView?
    
    required init(mapView: AGSMapView) {
        // TODO: Use a better method for figuring out cell sizes. This is copied from the original
        // implementation and is pretty much gibberish.
        let cellSizeInFeet = 1/12.0
        let mapUnits = AGSLinearUnit.meters()
        let screenUnits = AGSLinearUnit.feet()
        let cellSizeInMapUnits = screenUnits.convert(cellSizeInFeet, to: mapUnits)
        
        // Prepare a cluster provider for each LOD level
        var providerForPreviousLod: LODLevelGriddedClusterProvider<T>?
        for lodLevel in 0...19 {
            let lod = LODLevelGriddedClusterProvider<T>.lodForLevel(lodLevel)
            let cellSize = floor(cellSizeInMapUnits * lod.scale)
            let providerForLod = LODLevelGriddedClusterProvider<T>(cellSize: CGSize(width: cellSize, height: cellSize), zoomLevel: lodLevel)
            
            providerForLod.providerForPreviousLODLevel = providerForPreviousLod
            providerForPreviousLod?.providerForNextLODLevel = providerForLod
            providerForPreviousLod = providerForLod
            
            clusterProviders[lodLevel] = providerForLod
        }
        
        self.mapView = mapView
    }
    
    
    /// Return a cluster provider for a given map scale.
    ///
    /// - Parameter mapScale: The map scale being displayed
    /// - Returns: A cluster provider suitable for that map scale
    func clusterProvider(for mapScale: Double) -> LODLevelGriddedClusterProvider<T>? {
        for clusterProvider in clusterProviders.values {
            if clusterProvider.scaleInRange(scale: mapScale) {
                return clusterProvider
            }
        }
        return nil
    }
    
    
    func cluster(for key: GridClusterKey) -> LODLevelGeoElementCluster<T>? {
        let lodLevel = key.lod
        guard let providerForLOD = clusterProviders[lodLevel] else { return nil }
        return providerForLOD.cell(for: key).cluster
    }
    
    func cluster(for feature: AGSFeature) -> LODLevelGeoElementCluster<T>? {
        if let key = GridClusterKey(from: feature.attributes["Key"] as? String) {
            return cluster(for: key)
        }
        return nil
    }

//    Version if Key is an Int and globally unique across all LODs. Performance is O(n) to find a particular key,
//       but storage is smaller. Performance with complex key is O(1) but string parsing and memory footprint bigger.
//    func clusterForKey(key: GridClusterIndex) -> LODLevelGeoElementCluster<T>? {
//        for (lod, provider) in clusterProviders {
//            for cluster in provider.clusters {
//                if cluster.clusterKey == key {
//                    print("Found cluster \(key) in LOD \(lod)")
//                    return cluster
//                }
//            }
//        }
//        return nil
//    }

    
    
    /// Add items to be clustered.
    ///
    /// - Parameter items: Items of suitable type that will be clustered.
    func add<S: Sequence>(items: S) where S.Element == T {
        for (_, clusterProvider) in clusterProviders {
            clusterProvider.add(items: items)
        }
    }
    
    
    /// Remove all items from all providers being managed by this provider manager.
    func removeAllItems() {
        for (_, clusterProvider) in clusterProviders {
            clusterProvider.removeAllItems()
        }
    }

}
