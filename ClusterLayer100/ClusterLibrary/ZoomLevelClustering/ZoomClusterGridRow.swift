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

typealias ZoomClusterGridRow = Dictionary<Int, ZoomClusterGridCellsForRow>
typealias ZoomClusterGridCellsForRow = Dictionary<Int, ZoomClusterGridCell>

extension ZoomClusterGridRow {
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
