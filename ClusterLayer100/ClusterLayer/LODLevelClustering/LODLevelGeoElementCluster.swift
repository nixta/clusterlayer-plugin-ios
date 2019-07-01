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

class LODLevelGeoElementCluster<T: ClusterableGeoElement>: GeoElementCluster<T>, LODLevelCluster {
    
    weak var parentCluster: LODLevelGeoElementCluster<T>?

    var childClusters = Set<LODLevelGeoElementCluster<T>>()
    
    func add(childCluster: LODLevelGeoElementCluster<T>) {
        childCluster.parentCluster = self
        
        childClusters.insert(childCluster)
        items.formUnion(childCluster.items)
        
        invalidateAllGeometries()
    }
    
    func remove(childCluster: LODLevelGeoElementCluster<T>) {
        childCluster.parentCluster = nil
        
        childClusters.remove(childCluster)
        items.subtract(childCluster.items)
        
        invalidateAllGeometries()
    }

}
