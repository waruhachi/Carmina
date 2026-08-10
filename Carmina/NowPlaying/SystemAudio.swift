//
//  SystemAudio.swift
//  Carmina
//
//  Created by waru on 7/20/26.
//

import AVFoundation
import SwiftUI

#if os(iOS)
    import AVKit
    import MediaPlayer
#endif

@MainActor
@Observable
final class SystemAudio {
    private static let fallbackBluetoothSymbolName = "speaker.bluetooth.fill"

    var volume: Double = 0
    private var route: AudioOutputPresentation = .builtIn

    var routeName: String { route.name ?? "" }
    var routeSymbol: String { route.displaySymbolName }
    var routePickerSymbol: String? { route.symbolName }

    #if os(iOS)
        // Kept offscreen but in the hierarchy so setting its slider changes system volume.
        let volumeView = MPVolumeView(frame: .zero)

        private let session = AVAudioSession.sharedInstance()

        @ObservationIgnored private nonisolated(unsafe)
            var volumeObservation: NSKeyValueObservation?
        @ObservationIgnored private nonisolated(unsafe)
            var routeObserver: NSObjectProtocol?
        @ObservationIgnored private nonisolated(unsafe)
            var telephonyRouteObserver: NSObjectProtocol?
        @ObservationIgnored private var routeUpdateTask: Task<Void, Never>?

        init() {
            volume = Double(session.outputVolume)

            volumeObservation = session.observe(
                \.outputVolume,
                options: [.new]
            ) { [weak self] session, _ in
                let value = Double(session.outputVolume)
                Task { @MainActor [weak self] in
                    guard self?.volume != value else { return }
                    self?.volume = value
                }
            }

            routeObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleRouteUpdate() }
            }

            telephonyRouteObserver = NotificationCenter.default.addObserver(
                forName: CMPrivateBluetoothAdapter
                    .telephonyRoutesDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleRouteUpdate() }
            }

            updateRoute()
        }

        deinit {
            routeUpdateTask?.cancel()
            volumeObservation?.invalidate()
            if let routeObserver {
                NotificationCenter.default.removeObserver(routeObserver)
            }
            if let telephonyRouteObserver {
                NotificationCenter.default.removeObserver(
                    telephonyRouteObserver
                )
            }
        }

        func setVolume(_ value: Double) {
            let clamped = min(max(value, 0), 1)
            volume = clamped
            volumeSlider?.setValue(Float(clamped), animated: false)
        }

        private var volumeSlider: UISlider? {
            volumeView.subviews.compactMap { $0 as? UISlider }.first
        }

        private func scheduleRouteUpdate() {
            routeUpdateTask?.cancel()
            updateRoute()
            routeUpdateTask = Task { @MainActor [weak self] in
                // The audio-session and private route models can settle on
                // adjacent run-loop turns. Reconcile once without delaying
                // the first visible update.
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                self?.updateRoute()
            }
        }

        private func updateRoute() {
            guard let output = session.currentRoute.outputs.first else {
                setRoute(.builtIn)
                return
            }

            let updatedRoute: AudioOutputPresentation
            switch output.portType {
            case .builtInSpeaker, .builtInReceiver:
                updatedRoute = .builtIn
            case .headphones, .headsetMic:
                updatedRoute = AudioOutputPresentation(
                    name: output.portName,
                    symbolName: "headphones"
                )
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                updatedRoute = AudioOutputPresentation(
                    name: output.portName,
                    symbolName: CMPrivateBluetoothAdapter.symbolName(
                        forRouteUID: output.uid
                    ) ?? Self.fallbackBluetoothSymbolName
                )
            case .airPlay:
                updatedRoute = AudioOutputPresentation(
                    name: output.portName,
                    symbolName: "airplay.audio"
                )
            default:
                updatedRoute = AudioOutputPresentation(
                    name: output.portName,
                    symbolName: "speaker.wave.2"
                )
            }

            setRoute(updatedRoute)
        }

        private func setRoute(_ updatedRoute: AudioOutputPresentation) {
            guard route != updatedRoute else { return }
            route = updatedRoute
        }
    #else
        init() {}
        func setVolume(_ value: Double) { volume = value }
    #endif
}

#if os(iOS)
    struct VolumeHostView: UIViewRepresentable {
        let volumeView: MPVolumeView
        func makeUIView(context: Context) -> MPVolumeView { volumeView }
        func updateUIView(_ uiView: MPVolumeView, context: Context) {}
    }

    struct RoutePickerView: UIViewRepresentable {
        let symbolName: String?

        func makeUIView(context: Context) -> AudioRoutePickerContainerView {
            AudioRoutePickerContainerView(symbolName: symbolName)
        }

        func updateUIView(
            _ uiView: AudioRoutePickerContainerView,
            context: Context
        ) {
            uiView.setSymbol(symbolName)
        }
    }

    final class AudioRoutePickerContainerView: UIView {
        private let routePicker = AVRoutePickerView()
        private let symbolView = UIImageView()
        private var currentSymbolName: String?
        private var hasConfiguredSymbol = false

        init(symbolName: String?) {
            super.init(frame: .zero)

            routePicker.prioritizesVideoDevices = false
            routePicker.backgroundColor = .clear
            routePicker.translatesAutoresizingMaskIntoConstraints = false

            symbolView.contentMode = .center
            symbolView.isUserInteractionEnabled = false
            symbolView.tintColor = UIColor.white.withAlphaComponent(0.7)
            symbolView.translatesAutoresizingMaskIntoConstraints = false

            addSubview(routePicker)
            addSubview(symbolView)
            NSLayoutConstraint.activate([
                routePicker.leadingAnchor.constraint(equalTo: leadingAnchor),
                routePicker.trailingAnchor.constraint(equalTo: trailingAnchor),
                routePicker.topAnchor.constraint(equalTo: topAnchor),
                routePicker.bottomAnchor.constraint(equalTo: bottomAnchor),
                symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
                symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])

            setSymbol(symbolName)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            updateAppearance()
            bringSubviewToFront(symbolView)
        }

        func setSymbol(_ symbolName: String?) {
            guard !hasConfiguredSymbol || currentSymbolName != symbolName else {
                return
            }
            currentSymbolName = symbolName
            hasConfiguredSymbol = true

            let configuration = UIImage.SymbolConfiguration(
                pointSize: 22,
                weight: .regular
            )
            guard let symbolName,
                let image = UIImage(
                    systemName: symbolName,
                    withConfiguration: configuration
                )
            else {
                symbolView.image = nil
                symbolView.isHidden = true
                updateAppearance()
                return
            }

            symbolView.image = image
            symbolView.isHidden = false
            updateAppearance()
        }

        private func updateAppearance() {
            let isShowingCustomSymbol = !symbolView.isHidden
            routePicker.tintColor =
                isShowingCustomSymbol
                ? .clear
                : UIColor.white.withAlphaComponent(0.7)
            routePicker.activeTintColor =
                isShowingCustomSymbol ? .clear : .white
        }
    }
#endif
