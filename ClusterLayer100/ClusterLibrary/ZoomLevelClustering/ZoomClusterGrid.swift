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

typealias ZoomClusterGridRows = Dictionary<Int, ZoomClusterGridCellsForRow>
typealias ZoomClusterGridCellsForRow = Dictionary<Int, ZoomClusterGridCell>

extension ZoomClusterGridRows {
    mutating func getCell(grid: ZoomClusterGrid, row: Int, col: Int) -> ZoomClusterGridCell {
        var gridRow = self[row]
        if gridRow == nil {
            gridRow = ZoomClusterGridCellsForRow()
            self[row] = gridRow
        }
        var gridCell = gridRow![col]
        if gridCell == nil {
            gridCell = ZoomClusterGridCell(grid: grid, row: row, col: col)
            gridRow![col] = gridCell
        }
        return gridCell!
    }
}

class ZoomClusterGrid: ZoomLevelClusterGridProvider {
    static func makeManager() -> ZoomClusterGridManager {
        return ZoomClusterGridManager()
    }
    
    typealias GridManager = ZoomClusterGridManager
    
    // Minfill set of rows by Int ID from origin
    // Each row is a minfill set of columns by Int ID from origin
    // Origin is origin of the spatial reference of points added.
    var rows = ZoomClusterGridRows()
    
    var lod: AGSLevelOfDetail
    var cellSize: CGSize

    var zoomLevel: Int {
        return lod.level
    }
    
    var scale: Double {
        return lod.scale
    }
    
    func scaleInRange(scale: Double) -> Bool {
        if scale >= self.scale {
            if let prevLevelScale = gridForPrevZoomLevel?.scale, scale >= prevLevelScale {
                // This scale falls into another LOD range, not this one
                return false
            }
            // No previous LOD, or the range between this LOD scale and previous LOD scale covers it.
            return true
        }
        // Outside of this LOD range.
        return false
    }

    var gridForPrevZoomLevel: ZoomLevelClusterGridProvider?
    var gridForNextZoomLevel: ZoomLevelClusterGridProvider?
    
    var clusters: Set<Cluster> {
        return Set<Cluster>()
    }
    
    func addItems(geoElements: Array<AGSGeoElement>) {
        
    }
    
    func removeAllItems() {
        for (_, var row) in rows {
            for (_, clusterCell) in row {
                clusterCell.clusters.removeAll()
            }
            row.removeAll()
        }
        rows.removeAll()
    }
    
    func cellFor(row: Int, col: Int) -> ZoomClusterGridCell {
        return rows.getCell(grid: self, row: row, col: col)
    }
    
    func cellCentroid(for row: Int, col: Int) -> AGSPoint {
        return cellFor(row: row, col: col).center
    }
    
    init(cellSize: CGSize, zoomLevel: Int) {
        self.cellSize = cellSize
        lod = makeWebMercatorLod(level: zoomLevel)
    }
    
    func getGridCoordForMapPoint(mapPoint: AGSPoint) -> CGPoint {
        return CGPoint(x: floor(mapPoint.x/Double(cellSize.width)), y: floor(mapPoint.y/Double(cellSize.height)))
    }
    
    static func lodForLevel(_ level: Int) -> AGSLevelOfDetail {
        return makeWebMercatorLod(level: level)
    }
}


func makeWebMercatorLods(levels: Int) -> [AGSLevelOfDetail] {
    var lods:[AGSLevelOfDetail] = []
    for i in 0...levels {
        lods.append(makeWebMercatorLod(level: i))
    }
    return lods
}

func makeWebMercatorLod(level: Int) -> AGSLevelOfDetail {
    let res0 = 156543.03392800014, scale0 = 591657527.591555
    return AGSLevelOfDetail(level: level, resolution: res0/pow(2, Double(level)), scale: scale0/pow(2, Double(level)))
}
