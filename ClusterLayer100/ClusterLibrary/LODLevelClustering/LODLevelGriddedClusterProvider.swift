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

class LODLevelGriddedClusterProvider<T>: LODLevelClusterProvider where T: AGSGeoElement, T: Hashable {
    
    private class ZoomClusterGridRow {
        var cellsForRow = Dictionary<Int, LODLevelGriddedClusterGridCell<T>>()
    }
    
    // Minfill set of rows by Int ID from origin
    // Each row is a minfill set of columns by Int ID from origin
    // Origin is origin of the spatial reference of points added.
    private var rows = [Int: ZoomClusterGridRow]()
    
    var lod: AGSLevelOfDetail
    var cellSize: CGSize

    var lodLevel: Int {
        return lod.level
    }
    
    var scale: Double {
        return lod.scale
    }
    
    var providerForPreviousLODLevel: LODLevelGriddedClusterProvider?
    var providerForNextLODLevel: LODLevelGriddedClusterProvider?
    
    var items = Set<T>()
    
    var clusters: Set<GeoElementCluster<T>> {
        var clusters = Set<GeoElementCluster<T>>()
        for (_, row) in rows {
            for (_, cell) in row.cellsForRow {
                clusters.formUnion(cell.clusters)
            }
        }
        
        return clusters
    }

    
    init(cellSize: CGSize, zoomLevel: Int) {
        self.cellSize = cellSize
        lod = makeWebMercatorLod(level: zoomLevel)
    }

    
    func add<S: Sequence>(items: S) where S.Element == T {
        self.items.formUnion(items)
        
        var touchedClusters = Set<GeoElementCluster<T>>()
        var count = 0
        var skipped = 0
        for item in items {
            guard let itemLocation = item.geometry as? AGSPoint else {
                print("Skipping feature - it has no point!")
                skipped += 1
                continue
            }
            let cluster = getCluster(for: itemLocation)
            cluster.addPending(feature: item)
            count += 1
            touchedClusters.insert(cluster)
        }
        print("Touched \(touchedClusters.count) clusters while adding \(count) items and skipping \(skipped) [GeoElementCluster Size: \(cellSize)")
    }
    
    func removeAllItems() {
        for (_, row) in rows {
            for (_, clusterCell) in row.cellsForRow {
                clusterCell.clusters.removeAll()
            }
            row.cellsForRow.removeAll()
        }
        rows.removeAll()
    }
    
    func cellFor(row: Int, col: Int) -> LODLevelGriddedClusterGridCell<T> {
        return getCell(grid: self, rowId: row, colId: col)
    }
    
    func cellCentroid(for row: Int, col: Int) -> AGSPoint {
        return cellFor(row: row, col: col).center
    }
    
    func getCluster(for mapPoint: AGSPoint) -> GeoElementCluster<T> {
        let (row, col) = getGridCoordForMapPoint(mapPoint: mapPoint)
        let cell = cellFor(row: row, col: col)
        return cell.cluster
    }
    
    func getGridCoordForMapPoint(mapPoint: AGSPoint) -> (Int, Int) {
        let row = Int(floor(mapPoint.y/Double(cellSize.width)))
        let col = Int(floor(mapPoint.x/Double(cellSize.height)))
        return (row, col)
    }
    
    func scaleInRange(scale: Double) -> Bool {
        if scale >= self.scale {
            if let prevLevelScale = providerForPreviousLODLevel?.scale, scale >= prevLevelScale {
                // This scale falls into another LOD range, not this one
                return false
            }
            // No previous LOD, or the range between this LOD scale and previous LOD scale covers it.
            return true
        }
        // Outside of this LOD range.
        return false
    }
    
    static func lodForLevel(_ level: Int) -> AGSLevelOfDetail {
        return makeWebMercatorLod(level: level)
    }
    
    func getCell(grid: LODLevelGriddedClusterProvider, rowId: Int, colId: Int) -> LODLevelGriddedClusterGridCell<T> {
        var row = rows[rowId]
        if row == nil {
            row = ZoomClusterGridRow()
            rows[rowId] = row
        }
        var gridCell = row!.cellsForRow[colId]
        if gridCell == nil {
            gridCell = LODLevelGriddedClusterGridCell(size: grid.cellSize, row: rowId, col: colId)
            row!.cellsForRow[colId] = gridCell
        }
        return gridCell!
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
