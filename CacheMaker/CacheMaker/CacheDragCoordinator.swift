//
// Created by lai leon on 2020/12/3.
// Copyright (c) 2020 Razeware LLC. All rights reserved.
//
import UIKit

class CacheDragCoordinator {
    let sourceIndexPath: IndexPath
    var dragCompleted = false
    var isReordering = false

    init(sourceIndexPath: IndexPath) {
        self.sourceIndexPath = sourceIndexPath
    }
}

