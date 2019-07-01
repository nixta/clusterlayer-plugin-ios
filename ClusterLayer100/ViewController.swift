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

class ViewController: UIViewController, AGSGeoViewTouchDelegate {
    
    @IBOutlet weak var mapView: AGSMapView!
    
    let geodatabase = AGSGeodatabase(name: "stops")
    
    let map = AGSMap(basemapType: .streetsVector, latitude: 40.7128, longitude: -74.0060, levelOfDetail: 15)
    
    var clusterLayer: ClusterLayer<LODLevelGriddedClusterManager<AGSFeature>>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
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
            
            table.load(completion: { (error) in
                if let error = error {
                    print("Error loading table: \(error.localizedDescription)")
                    return
                }
                
                let clusterLayer = ClusterLayer<LODLevelGriddedClusterManager<AGSFeature>>(mapView: self.mapView, featureLayer: sourceLayer)
                
                self.map.operationalLayers.add(clusterLayer)
                
                self.clusterLayer = clusterLayer
            })
        }
        
        mapView.touchDelegate = self
    }
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        print("Map Scale: \(mapView.mapScale)")
        mapView.identifyLayers(atScreenPoint: screenPoint, tolerance: 20, returnPopupsOnly: false) { (results, error) in
            if let error = error {
                print("Error identifying! \(error.localizedDescription)")
                return
            }
            
            guard let results = results else { return }
            
            for result in results {
                print(result.layerContent.name)
                print(result.geoElements.map({ (element) -> NSMutableDictionary in
                    return element.attributes
                }))
                for subLayerResult in result.sublayerResults {
                    print(subLayerResult.layerContent.name)
                    print(subLayerResult.geoElements.map({ (element) -> NSMutableDictionary in
                        return element.attributes
                    }))
                }
            }
        }
    }
    
    @IBAction func showCoverages(_ sender: UISwitch) {
        clusterLayer.showCoverages = sender.isOn
    }
}
