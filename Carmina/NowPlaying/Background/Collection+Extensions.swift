//
//  Collection+Extensions.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
