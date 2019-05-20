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

class ZoomClusterGridManager: ClusterManager {

//    static func makeManager(mapView: AGSMapView) -> ZoomClusterGridManager {
//        return ZoomClusterGridManager(mapView: mapView)
//    }
    
    var grids: [Int : ZoomClusterGrid] = [:]
    
    func clusterProvider(for mapScale: Double) -> ZoomClusterGrid? {
        for grid in grids.values {
            if grid.scaleInRange(scale: mapScale) {
                return grid
            }
        }
        return nil
    }
    
    required init(mapView: AGSMapView) {
        let cellSizeInFeet = 1/12.0
        let mapUnits = AGSLinearUnit.meters()
        let screenUnits = AGSLinearUnit.feet()
        let cellSizeInMapUnits = screenUnits.convert(cellSizeInFeet, to: mapUnits)
        
        var prevGrid: ZoomClusterGrid?
        for lodLevel in 0...19 {
            let lod = ZoomClusterGrid.lodForLevel(lodLevel)
            let cellSize = floor(cellSizeInMapUnits * lod.scale)
            let gridForLod = ZoomClusterGrid(cellSize: CGSize(width: cellSize, height: cellSize), zoomLevel: lodLevel)
            
            gridForLod.gridForPrevZoomLevel = prevGrid
            prevGrid?.gridForNextZoomLevel = gridForLod
            prevGrid = gridForLod
            
            grids[lodLevel] = gridForLod
        }
    }
    
    func add(items: [AGSFeature]) {
        for (_, grid) in grids {
            grid.add(items: items)
        }
    }
}
