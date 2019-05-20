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


protocol Cluster {
    associatedtype ClusteredItem : Hashable
    associatedtype Key: Hashable
    
    var clusterKey: Key { get }
    
    var items: Set<ClusteredItem> { get }
    
    var centroid: AGSPoint? { get }
    var coverage: AGSPolygon? { get }
    var extent: AGSEnvelope? { get }
}

protocol ClusterProvider {
    associatedtype ClusterType: Cluster, Hashable
    
    var clusters: Set<ClusterType> { get }
    func add<T: Sequence>(items: T) where T.Element == AGSFeature
    func removeAllItems()
}

protocol ClusterManager {
    associatedtype ManagerType = Self
    associatedtype GridType
    
    static func makeManager(mapView: AGSMapView) -> ManagerType
    
    func gridForScale(mapScale: Double) -> GridType?
    
    func addFeatures(features: [AGSFeature])
}





protocol ZoomLevelCluster: Cluster {
    associatedtype ChildClusters : Hashable = Self
    
    var childClusters: Set<ChildClusters> { get }
}

protocol ZoomLevelClusterGridProvider: ClusterProvider {
    associatedtype SiblingGrids = Self
    
    var zoomLevel: Int { get }
    var scale: Double { get }
    var cellSize: CGSize { get }
    var gridForPrevZoomLevel: SiblingGrids? { get }
    var gridForNextZoomLevel: SiblingGrids? { get }
    func cellFor(row: Int, col: Int) -> ZoomClusterGridCell
}
