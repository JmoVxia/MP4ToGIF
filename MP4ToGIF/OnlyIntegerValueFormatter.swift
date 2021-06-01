//
//  OnlyIntegerValueFormatter.swift
//  MP4ToGIF
//
//  Created by Chen JmoVxia on 2021/5/27.
//  Copyright © 2021 Chen JmoVxia. All rights reserved.
//

import Cocoa

class OnlyIntegerValueFormatter: NumberFormatter {
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if partialString.count == 0 {
            return true
        }
        let scanner = Scanner.init(string: partialString)
        var intType: Int = 0
        if scanner.scanInt(&intType) && scanner.isAtEnd {
            return true
        }
        return false
    }
}
