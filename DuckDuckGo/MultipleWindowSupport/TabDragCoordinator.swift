//
//  TabDragCoordinator.swift
//  DuckDuckGo
//
//  Created by Meir Radnovich on 10 Heshvan 5781.
//  Copyright © 5781 DuckDuckGo. All rights reserved.
//

import Foundation

class TabDragCoordinator {
    private(set) var sourceIndexPaths: [IndexPath]
    var dragCompleted = false
    var isReordering: Bool {
        foreignSourcedTabs.isEmpty
    }
    private(set) var foreignSourcedTabs: [Tab] = []
    
    convenience init(sourceIndexPath: IndexPath) {
        init(sourceIndexPaths: [sourceIndexPath])
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