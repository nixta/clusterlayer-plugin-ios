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

import UIKit
import ArcGIS

class ViewController: UIViewController {
    
    @IBOutlet weak var mapView: AGSMapView!
    
    let geodatabase = AGSGeodatabase(name: "stops")
    
    var manager: LODLevelGriddedClusterManager?
    
    let map = AGSMap(basemapType: .streetsVector, latitude: 40.7128, longitude: -74.0060, levelOfDetail: 15)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
        manager = LODLevelGriddedClusterManager(mapView: mapView)
        
        mapView.map = map
        
        map.initialViewpoint = AGSViewpoint(targetExtent: AGSEnvelope(xMin: -13743980.503617, yMin: 5553033.545344,
                                                                      xMax: -13567177.320049, yMax: 5845311.308181,
                                                                      spatialReference: AGSSpatialReference.webMercator()))
        
        geodatabase.load { [weak self] (error) in
            if let error = error {
                print("Error loading geodatabase: \(error.localizedDescription)")
                return
            }
            
            guard let self = self, let table = self.geodatabase.geodatabaseFeatureTables.first else {
                return
            }

            let sourceLayer = AGSFeatureLayer(featureTable: table)
            self.map.operationalLayers.add(sourceLayer)
            
            let clusterLayer = ClusterLayer(mapView: self.mapView, featureLayer: sourceLayer)
            
            self.map.operationalLayers.add(clusterLayer)
        }
        
//        initGrid()
    }

    func initGrid() {
        AGSLoadObjects([map, geodatabase]) { [weak self, map, geodatabase] (allLoaded) in
            guard allLoaded else {
                [map, geodatabase].filter({$0.loadError != nil}).forEach({ print("error loading \($0): \($0.loadError!)")})
                return
            }
            
            guard let self = self, let table = self.geodatabase.geodatabaseFeatureTables.first else {
                return
            }
            
            let layer = AGSFeatureLayer(featureTable: table)
            map.operationalLayers.add(layer)
            
            layer.load(completion: { [layer] (error) in
                guard error == nil else { return }
                
                guard let extent = layer.fullExtent else { return }
                self.mapView.setViewpointGeometry(extent, completion: nil)
            })
            
            let params = AGSQueryParameters()
            params.whereClause = "1=1"
            table.queryFeatures(with: params, completion: { [weak self] (result, error) in
                if let error = error {
                    print("Error querying table: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self, let result = result, let manager = self.manager else { return }
                
                let features = result.featureEnumerator().allObjects
                
                print("Found \(features.count) features")

                for (_, grid) in manager.grids.sorted(by: { (item1, item2) -> Bool in
                    return item1.key < item2.key
                }) {
                    grid.add(items: features)
                }
                
                print("Added features to grids")

            })
        }
    }
}

