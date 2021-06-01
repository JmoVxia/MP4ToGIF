//
//  DragInView.swift
//  GIF2MP4
//
//  Created by Chen JmoVxia on 2020/9/3.
//  Copyright © 2020 Chen JmoVxia. All rights reserved.
//

import Cocoa


class DragInView: NSView {
    var logsUrlCallback: (([URL]) -> ())?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
extension DragInView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteBoard = sender.draggingPasteboard
        if let urls = (pasteBoard.readObjects(forClasses: [NSURL.self]) as? [URL]), urls.count > 0 {
            logsUrlCallback?(urls)
            return true
        }
        return false
    }
}
