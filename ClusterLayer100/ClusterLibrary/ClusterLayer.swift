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

class ClusterLayer<GridType: ClusterProvider>: AGSFeatureCollectionLayer {
    
    let grid: GridType!
    
    let manager = ZoomClusterGridManager()
    
    init(gridProvider: GridType) {
        grid = gridProvider

        let fields: [AGSField] = [
            AGSField(fieldType: .int32, name: "Key", alias: "Key", length: 0, domain: nil, editable: true, allowNull: false),
            AGSField(fieldType: .int16, name: "FeatureCount", alias: "Feature Count", length: 0, domain: nil, editable: true, allowNull: false)
        ]
        let fct = AGSFeatureCollectionTable(fields: fields, geometryType: .point, spatialReference: AGSSpatialReference.webMercator())
        let clusteredClass = AGSClassBreak(description: "Clustered", label: "Clustered", minValue: 10, maxValue: 1E6, symbol: AGSSimpleMarkerSymbol(style: .circle, color: .red, size: 25))
        let renderer = AGSClassBreaksRenderer(fieldName: "FeatureCount", classBreaks: [clusteredClass])
        fct.renderer = renderer
        let fc = AGSFeatureCollection(featureCollectionTables: [fct])
        
        super.init(featureCollection: fc)
    }
}

extension ClusterLayer where GridType == ZoomClusterGrid {
    func createBlankGridForLods() {
        let cellSizeInFeet = 0.25/12.0
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
        }
    }
}
