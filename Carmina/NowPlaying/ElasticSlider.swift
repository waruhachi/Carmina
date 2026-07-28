//
//  ElasticSlider.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct ElasticSlider<LeadingContent: View, TrailingContent: View>: View {
    @ObserveInjection var inject

    @Binding private var value: Double

    @Environment(\.elasticSliderConfig) var config
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var isActive: Bool = false

    @State private var lastStoredValue: CGFloat
    @State private var stretchingValue: CGFloat = 0
    @State private var viewSize: CGSize = .zero

    private let range: ClosedRange<Double>
    private let leadingLabel: LeadingContent?
    private let trailingLabel: TrailingContent?

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        leadingLabel: (() -> LeadingContent)? = nil,
        trailingLabel: (() -> TrailingContent)? = nil
    ) {
        _value = value
        self.range = range
        lastStoredValue = value.wrappedValue
        self.leadingLabel = leadingLabel?()
        self.trailingLabel = trailingLabel?()
    }

    var body: some View {
        Group {
            if config.labelLocation == .bottom {
                bottomLabeledTrack
            } else {
                sideLabeledTrack
            }
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.3, extraBounce: 0.3),
            value: isActive
        )
        .sensoryFeedback(trigger: value) { _, newValue in
            guard config.defaultSensoryFeedback else { return nil }
            if newValue >= range.upperBound { return .increase }
            if newValue <= range.lowerBound { return .decrease }
            return nil
        }
    }
}

extension ElasticSlider {
    @ViewBuilder
    fileprivate func styled<Content: View>(_ content: Content) -> some View {
        if config.syncLabelsStyle {
            ZStack {
                content
                    .foregroundStyle(config.maximumTrackColor)
                    .blendMode(config.blendMode)
                content
                    .foregroundStyle(
                        isActive
                            ? config.minimumTrackActiveColor
                            : config.minimumTrackInactiveColor
                    )
            }
            .animation(nil, value: isActive)
            .blendMode(isActive ? .normal : config.blendMode)
            .transformEffect(.identity)
        } else {
            content
        }
    }

    fileprivate var bottomLabeledTrack: some View {
        VStack(spacing: 0) {
            track
            HStack(spacing: 0) {
                let padding = (isActive ? 0 : config.growth) + config.maxStretch
                styled(leadingLabel)
                    .padding(.leading, padding - leadingStretch)
                Spacer()
                styled(trailingLabel)
                    .padding(.trailing, padding - trailingStretch)
            }
        }
    }

    fileprivate var sideLabeledTrack: some View {
        HStack(spacing: 0) {
            let padding = (isActive ? 0 : config.growth) + config.maxStretch
            styled(leadingLabel)
                .offset(x: padding - leadingStretch)
            track
            styled(trailingLabel)
                .offset(x: trailingStretch - padding)
        }
    }

    fileprivate var track: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Capsule()
                    .fill(config.maximumTrackColor)
                    .blendMode(config.blendMode)

                let fillWidth = max(
                    0,
                    normalized(value)
                        * trackWidth(for: size.width, active: isActive)
                        - leadingStretch
                        + trailingStretch
                )
                Capsule()
                    .fill(
                        isActive
                            ? config.minimumTrackActiveColor
                            : config.minimumTrackInactiveColor
                    )
                    .blendMode(isActive ? .normal : config.blendMode)
                    .mask(
                        Rectangle()
                            .frame(width: fillWidth)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
            }
            .preference(key: SizePreferenceKey.self, value: size)
            .frame(
                height: isActive
                    ? config.activeHeight - abs(normalizedStretchingValue)
                        * config.stretchNarrowing
                    : config.inactiveHeight
            )
            .padding(.horizontal, isActive ? 0 : config.growth)
            .padding(.leading, config.maxStretch - leadingStretch)
            .padding(.trailing, config.maxStretch - trailingStretch)
            .onPreferenceChange(SizePreferenceKey.self) { viewSize = $0 }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isActive) { _, out, _ in out = true }
                    .onChanged { value in
                        let progress =
                            (value.translation.width
                                / trackWidth(for: size.width, active: true))
                            * range.distance
                            + lastStoredValue
                        self.value = Double(progress).clamped(to: range)
                        if progress < range.lowerBound {
                            stretchingValue = normalized(
                                progress - range.lowerBound
                            )
                        }
                        if progress > range.upperBound {
                            stretchingValue = normalized(
                                progress - range.upperBound
                            )
                        }
                    }
                    .onEnded { _ in
                        lastStoredValue = value
                        stretchingValue = 0
                    }
            )
        }
        .frame(
            height: max(
                0,
                isActive
                    ? config.activeHeight - abs(normalizedStretchingValue)
                        * config.stretchNarrowing
                    : config.inactiveHeight
            )
        )
    }

    fileprivate var normalizedStretchingValue: CGFloat {
        guard config.maxStretch != 0 else { return 0 }
        let trackWidth = activeTrackWidth
        guard trackWidth != 0, viewSize.width > config.maxStretch * 2 else {
            return 0
        }
        let max = config.maxStretch / trackWidth / config.pushStretchRatio
        return stretchingValue.clamped(to: -max...max) / max
    }

    fileprivate var leadingStretch: CGFloat {
        let value = normalizedStretchingValue
        let stretch = abs(value) * config.maxStretch
        return value < 0 ? stretch : -stretch * config.pullStretchRatio
    }

    fileprivate var trailingStretch: CGFloat {
        let value = normalizedStretchingValue
        let stretch = abs(value) * config.maxStretch
        return stretchingValue > 0
            ? stretch : -stretch * config.pullStretchRatio
    }

    fileprivate func normalized(_ value: CGFloat) -> CGFloat {
        (value - range.lowerBound) / range.distance
    }

    fileprivate var activeTrackWidth: CGFloat {
        trackWidth(for: viewSize.width, active: true)
    }

    fileprivate func trackWidth(for viewWidth: CGFloat, active: Bool) -> CGFloat
    {
        max(
            0,
            viewWidth - config.maxStretch * 2 - (active ? 0 : config.growth * 2)
        )
    }
}

extension ElasticSlider where LeadingContent == EmptyView {
    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        trailingLabel: (() -> TrailingContent)? = nil
    ) {
        _value = value
        self.range = range
        lastStoredValue = value.wrappedValue
        leadingLabel = nil
        self.trailingLabel = trailingLabel?()
    }
}

extension ElasticSlider where TrailingContent == EmptyView {
    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        leadingLabel: (() -> LeadingContent)? = nil
    ) {
        _value = value
        self.range = range
        lastStoredValue = value.wrappedValue
        self.leadingLabel = leadingLabel?()
        trailingLabel = nil
    }
}

extension ElasticSlider
where LeadingContent == EmptyView, TrailingContent == EmptyView {
    init(value: Binding<Double>, in range: ClosedRange<Double>) {
        _value = value
        self.range = range
        lastStoredValue = value.wrappedValue
        leadingLabel = nil
        trailingLabel = nil
    }
}

struct ElasticSliderConfig {
    enum LabelLocation { case bottom, side }

    let labelLocation: LabelLocation
    let activeHeight: CGFloat
    let inactiveHeight: CGFloat
    let growth: CGFloat
    let stretchNarrowing: CGFloat
    let maxStretch: CGFloat
    let pushStretchRatio: CGFloat
    let pullStretchRatio: CGFloat
    let minimumTrackActiveColor: Color
    let minimumTrackInactiveColor: Color
    let maximumTrackColor: Color
    let blendMode: BlendMode
    let syncLabelsStyle: Bool
    let defaultSensoryFeedback: Bool

    init(
        labelLocation: LabelLocation = .side,
        activeHeight: CGFloat = 17,
        inactiveHeight: CGFloat = 7,
        growth: CGFloat = 9,
        stretchNarrowing: CGFloat = 4,
        maxStretch: CGFloat = 9,
        pushStretchRatio: CGFloat = 0.2,
        pullStretchRatio: CGFloat = 0.5,
        minimumTrackActiveColor: Color = .white,
        minimumTrackInactiveColor: Color = .white.opacity(0.3),
        maximumTrackColor: Color = .white.opacity(0.3),
        blendMode: BlendMode = .normal,
        syncLabelsStyle: Bool = false,
        defaultSensoryFeedback: Bool = true
    ) {
        self.labelLocation = labelLocation
        self.activeHeight = activeHeight
        self.inactiveHeight = inactiveHeight
        self.growth = growth
        self.stretchNarrowing = stretchNarrowing
        self.maxStretch = maxStretch
        self.pushStretchRatio = pushStretchRatio
        self.pullStretchRatio = pullStretchRatio
        self.minimumTrackActiveColor = minimumTrackActiveColor
        self.minimumTrackInactiveColor = minimumTrackInactiveColor
        self.maximumTrackColor = maximumTrackColor
        self.blendMode = blendMode
        self.syncLabelsStyle = syncLabelsStyle
        self.defaultSensoryFeedback = defaultSensoryFeedback
    }
}

extension ElasticSliderConfig {
    static var playbackProgress: Self {
        .init(
            labelLocation: .bottom,
            maxStretch: 0,
            minimumTrackActiveColor: .white,
            minimumTrackInactiveColor: .white.opacity(0.3),
            maximumTrackColor: .white.opacity(0.3),
            syncLabelsStyle: true
        )
    }
    static var volume: Self {
        .init(
            labelLocation: .side,
            maxStretch: 10,
            minimumTrackActiveColor: .white,
            minimumTrackInactiveColor: .white.opacity(0.3),
            maximumTrackColor: .white.opacity(0.3),
            syncLabelsStyle: true
        )
    }
}

extension View {
    func sliderStyle(_ config: ElasticSliderConfig) -> some View {
        environment(\.elasticSliderConfig, config)
    }
}

private struct ElasticSliderConfigEnvironmentKey: EnvironmentKey {
    static let defaultValue: ElasticSliderConfig = .init()
}

extension EnvironmentValues {
    var elasticSliderConfig: ElasticSliderConfig {
        get { self[ElasticSliderConfigEnvironmentKey.self] }
        set { self[ElasticSliderConfigEnvironmentKey.self] = newValue }
    }
}
