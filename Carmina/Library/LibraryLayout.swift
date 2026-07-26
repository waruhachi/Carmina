//
//  LibraryLayout.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

@Observable
final class LibraryLayout {
    var order: [LibrarySection] { didSet { persist() } }
    var hidden: Set<LibrarySection> { didSet { persist() } }

    private static let orderKey = "library.order"
    private static let hiddenKey = "library.hidden"

    init() {
        let d = UserDefaults.standard
        if let raw = d.stringArray(forKey: Self.orderKey) {
            let restored = raw.compactMap(LibrarySection.init(rawValue:))
            order =
                restored
                + LibrarySection.allCases.filter { !restored.contains($0) }
        } else {
            order = LibrarySection.allCases
        }
        hidden = Set(
            (d.stringArray(forKey: Self.hiddenKey) ?? []).compactMap(
                LibrarySection.init(rawValue:)
            )
        )
    }

    var visibleSections: [LibrarySection] {
        order.filter { !hidden.contains($0) }
    }
    func isVisible(_ s: LibrarySection) -> Bool { !hidden.contains(s) }
    func toggle(_ s: LibrarySection) {
        if hidden.contains(s) { hidden.remove(s) } else { hidden.insert(s) }
    }
    func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(order.map(\.rawValue), forKey: Self.orderKey)
        d.set(Array(hidden).map(\.rawValue), forKey: Self.hiddenKey)
    }
}
