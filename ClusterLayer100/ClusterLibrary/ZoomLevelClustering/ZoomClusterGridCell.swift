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

class ZoomClusterGridCell: ClusterCell, Hashable {
    var grid: ZoomLevelClusterGridProvider
    
    var row: Int
    var col: Int
    var clusters = Set<Cluster>()
    var cluster: Cluster {
        guard let clusterForCell = clusters.first else {
            let newCluster = Cluster()
            newCluster.containingCell = self
            clusters.insert(newCluster)
            return newCluster
        }
        return clusterForCell
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(row)
        hasher.combine(col)
    }
    
    static func == (lhs: ZoomClusterGridCell, rhs: ZoomClusterGridCell) -> Bool {
        return lhs.row == rhs.row && lhs.col == rhs.col
    }
    
    init(grid: ZoomClusterGrid, row: Int, col: Int) {
        self.grid = grid
        self.row = row
        self.col = col
    }
    
    var center: AGSPoint {
        return extent.center
    }
    
    lazy var extent: AGSEnvelope = {
        let cellSize = grid.cellSize
        let bl = AGSPoint(x: Double(row) * Double(cellSize.width), y: Double(col) * Double(cellSize.height), spatialReference: AGSSpatialReference.webMercator())
        let tr = AGSPoint(x: Double(row+1) * Double(cellSize.width), y: Double(col+1) * Double(cellSize.height), spatialReference: AGSSpatialReference.webMercator())
        return AGSEnvelope(min: bl, max: tr)
    }()
}
