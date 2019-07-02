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

internal struct GridCellIndex: Hashable, CustomStringConvertible {
    let lod: Int
    let row: Int
    let col: Int

    var description: String {
        return "\(lod).\(row).\(col)"
    }
    
    init?(from keyString: String?) {
        guard let str = keyString, let parts = str.split(separator: ".").map({ Int($0) }) as? [Int], parts.count == 3 else {
            return nil
        }
        
        lod = parts[0]
        row = parts[1]
        col = parts[2]
    }
    
    init(lod: Int, row: Int, col: Int) {
        self.lod = lod
        self.row = row
        self.col = col
    }
}

internal class LODLevelGriddedClusterGridCell<T: ClusterableGeoElement> {
    
    var index: GridCellIndex
    var size: CGSize
    
    var clusters = Set<LODLevelGeoElementCluster<T>>()

    // We understand the concept of multiple clusters per cell, but in this implementation there
    // is only every 1 cluster per call.
    var cluster: LODLevelGeoElementCluster<T> {
        guard let clusterForCell = clusters.first else {
            let newCluster = LODLevelGeoElementCluster<T>(key: index)
            clusters.insert(newCluster)
            return newCluster
        }
        return clusterForCell
    }
    
    var center: AGSPoint {
        return extent.center
    }
    
    lazy var extent: AGSEnvelope = {
        let bl = AGSPoint(x: Double(index.row) * Double(size.width), y: Double(index.col) * Double(size.height), spatialReference: AGSSpatialReference.webMercator())
        let tr = AGSPoint(x: Double(index.row+1) * Double(size.width), y: Double(index.col+1) * Double(size.height), spatialReference: AGSSpatialReference.webMercator())
        return AGSEnvelope(min: bl, max: tr)
    }()

    init(size: CGSize, index: GridCellIndex) {
        self.size = size
        self.index = index
    }

}
