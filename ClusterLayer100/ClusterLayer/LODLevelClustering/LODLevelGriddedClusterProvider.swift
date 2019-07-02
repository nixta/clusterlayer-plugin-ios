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

class LODLevelGriddedClusterProvider<T: ClusterableGeoElement>: LODLevelClusterProvider {
    var name: String {
        return "LOD Level \(lodLevel)"
    }

    typealias ClusterType = LODLevelGeoElementCluster<T>
    
    private class LODLevelGriddedClusterGridRow {
        var cellsForRow = Dictionary<Int, LODLevelGriddedClusterGridCell<T>>()
    }
    
    // Minfill set of rows by Int ID from origin
    // Each row is a minfill set of columns by Int ID from origin
    // Origin is origin of the spatial reference of points added.
    private var rows = [Int: LODLevelGriddedClusterGridRow]()
    
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
    
    var clusters: Set<ClusterType> {
        var clusters = Set<ClusterType>()
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
        var touchedClusters = Set<ClusterType>()
        var count = 0
        var skipped = 0
        for item in items {
            guard let itemLocation = item.geometry as? AGSPoint else {
                print("Skipping feature - it has no point!")
                skipped += 1
                continue
            }
            let cluster = self.cluster(for: itemLocation)
            cluster.addPending(item: item)
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
    
    func ensureClustersReadyForDisplay() {
        for cluster in clusters {
            cluster.flushPendingItemsIntoCluster()
        }
    }
    
    internal func cell(for cellIndex: GridCellIndex) -> LODLevelGriddedClusterGridCell<T> {
        var gridRowForCell = rows[cellIndex.row]
        if gridRowForCell == nil {
            gridRowForCell = LODLevelGriddedClusterGridRow()
            rows[cellIndex.row] = gridRowForCell
        }
        var cell = gridRowForCell!.cellsForRow[cellIndex.col]
        if cell == nil {
            cell = LODLevelGriddedClusterGridCell(size: self.cellSize, index: cellIndex)
            gridRowForCell!.cellsForRow[cellIndex.col] = cell
        }
        return cell!
    }
    
    private func cellCentroid(for cellIndex: GridCellIndex) -> AGSPoint {
        return cell(for: cellIndex).center
    }
    
    func cluster(for key: GridCellIndex) -> LODLevelGeoElementCluster<T>? {
        return cell(for: key).cluster
    }

    func cluster(for mapPoint: AGSPoint) -> ClusterType {
        let cellIndex = getGridCoordForMapPoint(mapPoint: mapPoint)
        return cluster(for: cellIndex)!
    }
    
    func getGridCoordForMapPoint(mapPoint: AGSPoint) -> GridCellIndex {
        let row = Int(floor(mapPoint.y/Double(cellSize.width)))
        let col = Int(floor(mapPoint.x/Double(cellSize.height)))
        return GridCellIndex(lod: lodLevel, row: row, col: col)
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
    
    static func == (lhs: LODLevelGriddedClusterProvider<T>, rhs: LODLevelGriddedClusterProvider<T>) -> Bool {
        return lhs === rhs
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
