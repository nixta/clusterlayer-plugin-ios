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

extension Cluster {
    
    func calculateCentroid<T: Sequence>(features: T) -> AGSPoint where T.Element == AGSFeature {
        let points = features.compactMap { (feature) -> AGSPoint? in
            if let pt = feature.geometry as? AGSPoint {
                return pt
            } else {
                return feature.geometry?.extent.center
            }
        }
        
        guard points.count > 0 else {
            assertionFailure("Attempting to get centroid for empty cluster!")
            return containingCell.center
        }
        
        if points.count == 1 {
            return points.first!
        }
        
        var totalX: Double = 0
        var totalY: Double = 0
        var count = 0
        
        var sr: AGSSpatialReference?
        for feature in features {
            guard let featurePoint = feature.geometry as? AGSPoint else { continue }
            
            if sr == nil { sr = featurePoint.spatialReference }
            
            totalX += featurePoint.x
            totalY += featurePoint.y
            count += 1
        }
        
        return AGSPoint(x: totalX/Double(count), y: totalY/Double(count), spatialReference: sr)
    }
    
}
