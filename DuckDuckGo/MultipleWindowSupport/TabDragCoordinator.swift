//
//  TabDragCoordinator.swift
//  DuckDuckGo
//
//  Created by Meir Radnovich on 10 Heshvan 5781.
//  Copyright © 5781 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//

import UIKit

class TabDragCoordinator {
    private(set) var sourceIndexPaths: [IndexPath]
    var dragCompleted = false
    var isReordering = false
    private(set) var foreignSourcedTabs: [Tab] = []
    
    convenience init(sourceIndexPath: IndexPath) {
        self.init(sourceIndexPaths: [sourceIndexPath])
    }
    
    init(sourceIndexPaths: [IndexPath]) {
        self.sourceIndexPaths = sourceIndexPaths
    }
    
    func add(indexPath: IndexPath) {
        sourceIndexPaths.append(indexPath)
    }
    
    func add(foreignTab tab: Tab) {
        foreignSourcedTabs.append(tab)
    }
}
