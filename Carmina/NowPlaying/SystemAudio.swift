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
    var volume: Double = 0
    var routeName: String = ""
    var routeSymbol: String = "airplay.audio"

    #if os(iOS)
        // Kept offscreen but in the hierarchy so setting its slider changes system volume.
        let volumeView = MPVolumeView(frame: .zero)

        private let session = AVAudioSession.sharedInstance()

        @ObservationIgnored private nonisolated(unsafe)
            var volumeObservation: NSKeyValueObservation?
        @ObservationIgnored private nonisolated(unsafe)
            var routeObserver: NSObjectProtocol?

        init() {
            volume = Double(session.outputVolume)
            updateRoute()

            volumeObservation = session.observe(
                \.outputVolume,
                options: [.new]
            ) { [weak self] session, _ in
                let value = Double(session.outputVolume)
                Task { @MainActor [weak self] in self?.volume = value }
            }

            routeObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.updateRoute() }
            }
        }

        deinit {
            volumeObservation?.invalidate()
            if let routeObserver {
                NotificationCenter.default.removeObserver(routeObserver)
            }
        }

        func setVolume(_ value: Double) {
            volume = value
            guard
                let slider = volumeView.subviews
                    .compactMap({ $0 as? UISlider }).first
            else { return }
            slider.value = Float(value)
        }

        private func updateRoute() {
            guard let output = session.currentRoute.outputs.first else {
                routeName = ""
                return
            }
            switch output.portType {
            case .builtInSpeaker, .builtInReceiver:
                routeName = ""
            default:
                routeName = output.portName
            }
        }

        private func bluetoothSymbol(for name: String) -> String {
            let n = name.lowercased()
            if n.contains("airpods max") { return "airpods.max" }
            if n.contains("airpods pro") { return "airpods.pro" }
            if n.contains("airpods") { return "airpods" }
            if n.contains("powerbeats pro 2") {
                return "beats.powerbeats.pro.2"
            }
            if n.contains("powerbeats pro") { return "beats.powerbeats.pro" }
            if n.contains("powerbeats3") || n.contains("powerbeats 3") {
                return "beats.powerbeats3"
            }
            if n.contains("powerbeats") { return "beats.earphones" }
            if n.contains("fit pro") { return "beats.fitpro" }
            if n.contains("studio buds+") || n.contains("studio buds plus") {
                return "beats.studiobuds.plus"
            }
            if n.contains("studio buds") { return "beats.studiobuds" }
            if n.contains("solo buds") { return "beats.solobuds" }
            if n.contains("pill") { return "beats.pill" }
            if n.contains("beats") { return "beats.headphones" }
            return "airplay.audio"
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
        func makeUIView(context: Context) -> AVRoutePickerView {
            let view = AVRoutePickerView()
            view.prioritizesVideoDevices = false
            view.tintColor = UIColor.white.withAlphaComponent(0.7)
            view.activeTintColor = UIColor.white
            view.backgroundColor = .clear
            return view
        }
        func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
    }
#endif
