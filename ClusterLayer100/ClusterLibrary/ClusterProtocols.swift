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

protocol ClusterManager {
    associatedtype ClusterProviderType : ClusterProvider
    typealias ClusterType = ClusterProviderType.ClusterType
    typealias ItemType = ClusterType.ItemType
    
    init(mapView: AGSMapView)
    
    func clusterProvider(for mapScale: Double) -> ClusterProviderType?
    
    func add<S: Sequence>(items: S) where S.Element == ClusterType.ItemType
    func removeAllItems()
}

protocol ClusterProvider: Equatable {
    associatedtype ClusterType: Cluster
    associatedtype ItemType = ClusterType.ItemType
    
    var clusters: Set<ClusterType> { get }
    func getCluster(for mapPoint: AGSPoint) -> ClusterType
    
    func add<S: Sequence>(items: S) where S.Element == ItemType
    func removeAllItems()
    
    func ensureClustersReadyForDisplay()
}

protocol Cluster: Hashable {
    associatedtype ItemType : Hashable
    associatedtype Key: Hashable
    
    var clusterKey: Key { get }
    
    var items: Set<ItemType> { get }
    var itemCount: Int { get }
    
    var centroid: AGSPoint? { get }
    var coverage: AGSPolygon? { get }
    var extent: AGSEnvelope? { get }

    func add<S: Sequence>(items: S) where S.Element == ItemType
    func removeAllItems()
}
