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

extension Set where Element: Cluster {
    
    internal func asFeatures(in table: AGSFeatureTable, for component: ClusterLayerComponent, minClusterCount: Int = 2) -> [AGSFeature] {
        switch component {
        case .items:
            return self.flatMap({ (cluster) -> [AGSFeature] in
                if cluster.itemCount < minClusterCount {
                    // If we should be displaying the features, return them
                    return cluster.items.compactMap({ (item) -> AGSFeature? in
                        return item as? AGSFeature
                    })
                } else {
                    // We should be displaying as a cluster, so don't return any items.
                    return []
                }
            })
        case .clusters, .coverages:
            return self.compactMap({ (cluster) -> AGSFeature? in
                guard let geometry: AGSGeometry? = {
                    switch component {
                    case .clusters:
                        // If we should explode the cluster, return nil for the cluster geometry.
                        // A separate call to this function with displayType == .items will then
                        // make sure the features are displayed.
                        if cluster.itemCount >= minClusterCount {
                            return cluster.centroid
                        } else {
                            return nil
                        }
                    case .coverages:
                        return cluster.coverage
                    default:
                        return nil
                    } }() else {
                        //                        print("Skipping feature - could not get suitable geometry for type!")
                        return nil
                }
                
                let attributes: [String : Any] = [
                    "Key": "\(cluster.clusterKey)",
                    "FeatureCount": cluster.itemCount,
                    "ShouldDisplayItems": cluster.itemCount >= minClusterCount ? 0 : -1
                ]
                
                return table.createFeature(attributes: attributes, geometry: geometry)
            })
        }
    }
    
}

