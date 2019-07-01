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

// Copied from http://blog.flaviocaetano.com/post/the-simplest-throttle-slash-debounce-youll-ever-see/

import Dispatch

private struct DebounceItem {
    let deadline: DispatchTime
    let workItem: DispatchWorkItem
}

private var throttleWorkItems = [AnyHashable: DispatchWorkItem]()
private var lastDebounces = [AnyHashable: DebounceItem]()
private let nilContext: AnyHashable = arc4random()

public extension DispatchQueue {
    
    /**
     - parameters:
     - deadline: The timespan to delay a closure execution
     - context: The context in which the throttle should be executed
     - action: The closure to be executed
     Delays a closure execution and ensures no other executions are made during deadline
     */
    func throttle(deadline: DispatchTime, context: AnyHashable? = nil, action: @escaping () -> Void) {
        let worker = DispatchWorkItem {
            defer { throttleWorkItems.removeValue(forKey: context ?? nilContext) }
            action()
        }
        
        asyncAfter(deadline: deadline, execute: worker)
        
        throttleWorkItems[context ?? nilContext]?.cancel()
        throttleWorkItems[context ?? nilContext] = worker
    }
    
    /**
     - parameters:
     - interval: The interval in which new calls will be ignored
     - context: The context in which the debounce should be executed
     - action: The closure to be executed
     Executes a closure and ensures no other executions will be made during the interval.
     */
    func debounce(interval: Double, context: AnyHashable? = nil, action: @escaping () -> Void) {
        let wrappedAction = {
            action()
        }
        
        let debounceWorkItem = DispatchWorkItem(block: wrappedAction)
        let debounceItem = DebounceItem(deadline: .now() + interval, workItem: debounceWorkItem)
        asyncAfter(deadline: debounceItem.deadline, execute: debounceItem.workItem)

        if let last = lastDebounces[context ?? nilContext], last.deadline > .now() {
            // When the debounce activates, we want to use the most recent parameters, so replace the item that's
            // waiting with the same ultimate deadline.
            last.workItem.cancel()
            lastDebounces[context ?? nilContext] = debounceItem
        }
        
        lastDebounces[context ?? nilContext] = debounceItem
        
        // Cleanup & release context
        throttle(deadline: debounceItem.deadline + 2) {
            lastDebounces.removeValue(forKey: context ?? nilContext)
        }
    }
}
