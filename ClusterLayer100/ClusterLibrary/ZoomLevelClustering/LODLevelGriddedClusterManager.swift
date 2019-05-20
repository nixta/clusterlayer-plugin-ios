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

class LODLevelGriddedClusterManager: ClusterManager {
    
    var grids: [Int : LODLevelGriddedClusterProvider] = [:]
    
    required init(mapView: AGSMapView) {
        let cellSizeInFeet = 1/12.0
        let mapUnits = AGSLinearUnit.meters()
        let screenUnits = AGSLinearUnit.feet()
        let cellSizeInMapUnits = screenUnits.convert(cellSizeInFeet, to: mapUnits)
        
        var prevGrid: LODLevelGriddedClusterProvider?
        for lodLevel in 0...19 {
            let lod = LODLevelGriddedClusterProvider.lodForLevel(lodLevel)
            let cellSize = floor(cellSizeInMapUnits * lod.scale)
            let gridForLod = LODLevelGriddedClusterProvider(cellSize: CGSize(width: cellSize, height: cellSize), zoomLevel: lodLevel)
            
            gridForLod.providerForPreviousLODLevel = prevGrid
            prevGrid?.providerForNextLODLevel = gridForLod
            prevGrid = gridForLod
            
            grids[lodLevel] = gridForLod
        }
    }
    
    func clusterProvider(for mapScale: Double) -> LODLevelGriddedClusterProvider? {
        for grid in grids.values {
            if grid.scaleInRange(scale: mapScale) {
                return grid
            }
        }
        return nil
    }
    
    func add(items: [AGSFeature]) {
        for (_, grid) in grids {
            grid.add(items: items)
        }
    }
}
