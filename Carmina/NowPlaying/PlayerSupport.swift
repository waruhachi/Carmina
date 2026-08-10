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

private struct SongSwipeGestureModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var offset: CGFloat
    let canPrevious: Bool
    let canNext: Bool
    let pageWidth: CGFloat
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSwipeDown: (() -> Void)?

    @State private var isCompletingSwipe = false
    @State private var isHorizontalDrag: Bool?

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .local)
                .onChanged { value in
                    guard !isCompletingSwipe, !reduceMotion else { return }

                    let horizontal = value.translation.width
                    let vertical = value.translation.height

                    if isHorizontalDrag == nil {
                        isHorizontalDrag =
                            abs(horizontal) > abs(vertical) * 1.15
                    }
                    guard isHorizontalDrag == true else { return }

                    let canNavigate = horizontal > 0 ? canPrevious : canNext
                    offset =
                        canNavigate
                        ? horizontal : horizontal * 0.15
                }
                .onEnded { value in
                    guard !isCompletingSwipe else { return }

                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    let handledHorizontalDrag = isHorizontalDrag == true
                    isHorizontalDrag = nil

                    guard handledHorizontalDrag else {
                        resetOffset()
                        handleVerticalDrag(value, vertical: vertical)
                        return
                    }

                    let projected = value.predictedEndTranslation.width
                    let travel =
                        abs(projected) > abs(horizontal)
                        ? projected : horizontal
                    let isPrevious = horizontal > 0
                    let canNavigate = isPrevious ? canPrevious : canNext

                    guard abs(travel) >= 60, canNavigate else {
                        resetOffset()
                        return
                    }

                    guard !reduceMotion else {
                        offset = 0
                        navigate(isPrevious: isPrevious)
                        return
                    }

                    completeSwipe(isPrevious: isPrevious)
                }
        )
    }

    private func resetOffset() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            offset = 0
        }
    }

    private func completeSwipe(isPrevious: Bool) {
        isCompletingSwipe = true
        let settledOffset = isPrevious ? pageWidth : -pageWidth

        withAnimation(.smooth(duration: 0.16)) {
            offset = settledOffset
        } completion: {
            navigate(isPrevious: isPrevious)

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                offset = 0
            }
            isCompletingSwipe = false
        }
    }

    private func navigate(isPrevious: Bool) {
        if isPrevious {
            onPrevious()
        } else {
            onNext()
        }
    }

    private func handleVerticalDrag(
        _ value: DragGesture.Value,
        vertical: CGFloat
    ) {
        guard let onSwipeDown, vertical > 0 else { return }

        let projected = value.predictedEndTranslation.height
        let travel = max(vertical, projected)
        guard travel >= 80 else { return }

        onSwipeDown()
    }
}

extension View {
    func songSwipeGesture(
        offset: Binding<CGFloat>,
        canPrevious: Bool,
        canNext: Bool,
        pageWidth: CGFloat,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onSwipeDown: (() -> Void)? = nil
    ) -> some View {
        modifier(
            SongSwipeGestureModifier(
                offset: offset,
                canPrevious: canPrevious,
                canNext: canNext,
                pageWidth: pageWidth,
                onPrevious: onPrevious,
                onNext: onNext,
                onSwipeDown: onSwipeDown
            )
        )
    }
}

struct SongTextPager<Content: View>: View {
    let previousSong: Song?
    let currentSong: Song?
    let nextSong: Song?
    let offset: CGFloat
    let height: CGFloat
    @Binding var pageWidth: CGFloat
    @ViewBuilder let content: (Song?) -> Content

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fadeWidth = min(24, width * 0.08)
            let fadeLocation = width > 0 ? fadeWidth / width : 0
            let fadeProgress = min(abs(offset) / max(fadeWidth, 1), 1)

            ZStack(alignment: .leading) {
                if let previousSong {
                    content(previousSong)
                        .frame(
                            width: width,
                            height: height,
                            alignment: .leading
                        )
                        .offset(x: offset - width)
                }

                content(currentSong)
                    .frame(
                        width: width,
                        height: height,
                        alignment: .leading
                    )
                    .offset(x: offset)

                if let nextSong {
                    content(nextSong)
                        .frame(
                            width: width,
                            height: height,
                            alignment: .leading
                        )
                        .offset(x: offset + width)
                }
            }
            .frame(width: width, height: height, alignment: .leading)
            .clipped()
            .mask {
                LinearGradient(
                    stops: [
                        .init(
                            color: .black.opacity(1 - fadeProgress),
                            location: 0
                        ),
                        .init(color: .black, location: fadeLocation),
                        .init(color: .black, location: 1 - fadeLocation),
                        .init(
                            color: .black.opacity(1 - fadeProgress),
                            location: 1
                        ),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .onAppear { pageWidth = width }
            .onChange(of: width) { pageWidth = width }
        }
        .frame(height: height)
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
