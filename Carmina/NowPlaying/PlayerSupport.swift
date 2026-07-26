//
//  PlayerSupport.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

extension ClosedRange where Bound: AdditiveArithmetic {
    var distance: Bound { upperBound - lowerBound }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

struct SizePreferenceKey: PreferenceKey {
    nonisolated static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

func delay(_ delay: Double, closure: @escaping @Sendable () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: closure)
}

@inline(__always)
func lerp<V: BinaryFloatingPoint, T: BinaryFloatingPoint>(
    _ v0: V,
    _ v1: V,
    _ t: T
) -> V {
    v0 + V(t) * (v1 - v0)
}
