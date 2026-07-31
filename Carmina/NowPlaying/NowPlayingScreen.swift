//
//  NowPlayingScreen.swift
//  Carmina
//
//  Created by waru on 7/16/26.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct NowPlayingScreen: View {
    @ObserveInjection var inject

    @AppStorage("fullscreenArtwork") private var fullscreenArtwork = false

    @Environment(PlayerCoordinator.self) private var player
    @Environment(Library.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var transportHaptic = 0
    @State private var systemAudio = SystemAudio()
    @State private var artImage: Image?
    @State private var artworkAspect: CGFloat = 1
    @State private var palette: [Color] = []
    @State private var minVolumeTrigger = false
    @State private var maxVolumeTrigger = false
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var backwardTrigger: PlayerButtonTrigger = .one(
        bouncing: false
    )
    @State private var forwardTrigger: PlayerButtonTrigger = .one(
        bouncing: false
    )

    private var progress: Binding<Double> {
        Binding(get: { player.currentTime }, set: { player.seek(to: $0) })
    }

    private var volume: Binding<Double> {
        Binding(get: { systemAudio.volume }, set: { systemAudio.setVolume($0) })
    }

    private var dominant: Color { palette.first ?? .black }

    private var artworkBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .secondarySystemBackground)
        #else
            Color.gray.opacity(0.2)
        #endif
    }

    private var hasLyrics: Bool {
        !(player.current?.lyrics?.isEmpty ?? true)
    }

    private var scrimOpacity: Double { contrast == .increased ? 0.75 : 0.55 }

    var body: some View {
        Group {
            if fullscreenArtwork {
                fullscreenBody
            } else {
                squareBody
            }
        }
        .foregroundStyle(.white)
        #if os(iOS)
            .overlay(alignment: .bottom) {
                VolumeHostView(volumeView: systemAudio.volumeView)
                .frame(width: 1, height: 1)
                .opacity(0.00001)
                .allowsHitTesting(false)
            }
        #endif
        .task(id: player.current) { await refreshArtwork() }
        .sensoryFeedback(.impact(weight: .light), trigger: transportHaptic)
        .sheet(isPresented: $showLyrics) {
            LyricsView(
                title: player.current?.title ?? "",
                lyrics: player.current?.lyrics ?? ""
            )
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
    }

    private func refreshArtwork() async {
        guard let song = player.current else {
            artImage = nil
            palette = []
            artworkAspect = 1
            return
        }
        #if canImport(MediaPlayer)
            let ui = library.artworkUIImage(for: song)
            artImage = ui.map { Image(uiImage: $0) }
            if let ui {
                artworkAspect = ui.size.width / max(ui.size.height, 1)
            }
            if let ui,
                let colors = ui.dominantColorFrequencies(with: .high)?
                    .map({ Color($0.color) }),
                !colors.isEmpty
            {
                palette = colors
            }
        #endif
    }
}

// MARK: - Layouts

extension NowPlayingScreen {
    fileprivate var fullscreenBody: some View {
        ZStack(alignment: .top) {
            background
            coverLayer
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                controlStack
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)
            }
            grip
        }
    }

    fileprivate var squareBody: some View {
        VStack(spacing: 0) {
            grip
            squareArtwork
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            controlStack
                .padding(.horizontal, 28)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(meshBackground)
    }

    fileprivate var grip: some View {
        Capsule().fill(.white.opacity(0.5)).frame(width: 60, height: 4)
            .padding(.top, 8)
    }
}

// MARK: - Full-screen artwork

extension NowPlayingScreen {
    fileprivate var background: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let artImage {
                    artImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 80, opaque: true)
                } else {
                    dominant
                }
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(
                            color: .black.opacity(scrimOpacity),
                            location: 0.80
                        ),
                        .init(
                            color: .black.opacity(scrimOpacity),
                            location: 1.0
                        ),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    fileprivate var coverLayer: some View {
        GeometryReader { geo in
            Group {
                if let artImage {
                    artImage.resizable().scaledToFill()
                } else {
                    Color.clear
                }
            }
            .frame(width: geo.size.width, height: geo.size.height * 0.64)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.55),
                        .init(color: .black.opacity(0.45), location: 0.80),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Square artwork (original)

extension NowPlayingScreen {
    fileprivate var squareArtwork: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let small = !player.isPlaying
            let nonSquare = abs(artworkAspect - 1) > 0.1

            let playingPad: CGFloat = nonSquare ? 48 : 0
            let pausedPad: CGFloat = nonSquare ? 90 : 50
            let pad = small ? pausedPad : playingPad

            let playingOffsetY: CGFloat = 10
            let pausedOffsetY: CGFloat = 10
            let offsetY = small ? pausedOffsetY : playingOffsetY

            Group {
                if let artImage {
                    artImage.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.clear
                }
            }
            .background(artworkBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(pad)
            .shadow(
                color: Color(
                    .sRGBLinear,
                    white: 0,
                    opacity: small ? 0.13 : 0.33
                ),
                radius: small ? 3 : 8,
                y: small ? 3 : 10
            )
            .frame(width: side, height: side)
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(y: offsetY)
            .animation(reduceMotion ? nil : .smooth, value: player.isPlaying)
        }
        .padding(.horizontal, 25)
    }

    fileprivate var meshBackground: some View {
        #if canImport(UIKit)
            ColorfulBackground(colors: palette)
                .overlay(.black.opacity(contrast == .increased ? 0.4 : 0.25))
                .ignoresSafeArea()
        #else
            NowPlayingBackground(colors: palette)
        #endif
    }
}

// MARK: - Control stacks

extension NowPlayingScreen {
    fileprivate var controlStack: some View {
        VStack(spacing: 0) {
            titleRow
            scrubber.padding(.top, 18)
            controls.padding(.top, 22)
            volumeSlider.padding(.top, 40)
            footer
        }
    }
}

// MARK: - Shared control rows

extension NowPlayingScreen {
    fileprivate var titleRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(player.current?.title ?? "")
                    .font(.title3.weight(.semibold))
                    .id(player.current?.title ?? "")
                MarqueeText(player.current?.artist ?? "")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .id(player.current?.artist ?? "")
            }
            Spacer(minLength: 8)
            if let song = player.current {
                Menu {
                    SongMenu(song: song)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .tint(.primary)
                .accessibilityLabel("More")
            }
        }
    }

    fileprivate var scrubber: some View {
        ElasticSlider(
            value: progress,
            in: 0...max(player.duration, 1),
            leadingLabel: {
                Text(player.currentTime.asTimeString(style: .positional))
                    .font(.caption.weight(.semibold)).padding(.top, 8)
            },
            trailingLabel: {
                Text(
                    ((player.duration - player.currentTime) * -1)
                        .asTimeString(style: .positional)
                ).font(.caption.weight(.semibold)).padding(.top, 8)
            }
        )
        .sliderStyle(.playbackProgress)
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            if let quality = player.audioQuality {
                Text(quality)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(player.currentTime.asTimeString(style: .positional))
        .accessibilityAdjustableAction { direction in
            let step = max(player.duration * 0.05, 5)
            switch direction {
            case .increment:
                player.seek(to: min(player.currentTime + step, player.duration))
            case .decrement:
                player.seek(to: max(player.currentTime - step, 0))
            @unknown default:
                break
            }
        }
    }

    fileprivate var controls: some View {
        HStack(spacing: 24) {
            PlayerButton(
                label: {
                    PlayerButtonLabel(
                        type: .backward,
                        size: 34,
                        animationTrigger: backwardTrigger
                    )
                },
                onEnded: {
                    backwardTrigger.toggle(bouncing: true)
                    transportHaptic += 1
                    player.previous()
                }
            )
            .accessibilityLabel("Previous track")
            .accessibilityAddTraits(.isButton)

            PlayerButton(
                label: {
                    PlayerButtonLabel(
                        type: player.isPlaying ? .pause : .play,
                        size: 34
                    )
                },
                onEnded: {
                    transportHaptic += 1
                    player.togglePlayPause()
                }
            )
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            .accessibilityAddTraits(.isButton)

            PlayerButton(
                label: {
                    PlayerButtonLabel(
                        type: .forward,
                        size: 34,
                        animationTrigger: forwardTrigger
                    )
                },
                onEnded: {
                    forwardTrigger.toggle(bouncing: true)
                    transportHaptic += 1
                    player.next()
                }
            )
            .accessibilityLabel("Next track")
            .accessibilityAddTraits(.isButton)
        }
        .playerButtonStyle(
            .init(
                size: 68,
                labelColor: .white,
                tint: .white.opacity(0.2),
                pressedColor: .white
            )
        )
    }

    fileprivate var volumeSlider: some View {
        ElasticSlider(
            value: volume,
            in: 0...1,
            leadingLabel: {
                Image(systemName: "speaker.fill")
                    .padding(.trailing, 10)
                    .symbolEffect(.bounce, value: minVolumeTrigger)
            },
            trailingLabel: {
                Image(systemName: "speaker.wave.3.fill")
                    .padding(.leading, 10)
                    .symbolEffect(.bounce, value: maxVolumeTrigger)
            }
        )
        .sliderStyle(.volume)
        .font(.footnote)
        .frame(height: 50)
        .padding(.horizontal, -10)
        .onChange(of: systemAudio.volume) {
            guard !reduceMotion else { return }
            if systemAudio.volume == 0 { minVolumeTrigger.toggle() }
            if systemAudio.volume == 1 { maxVolumeTrigger.toggle() }
        }
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue(
            "\(Int((systemAudio.volume * 100).rounded())) percent"
        )
        .accessibilityAdjustableAction { direction in
            let step = 0.0625
            switch direction {
            case .increment:
                systemAudio.setVolume(min(systemAudio.volume + step, 1))
            case .decrement:
                systemAudio.setVolume(max(systemAudio.volume - step, 0))
            @unknown default:
                break
            }
        }
    }

    fileprivate var footer: some View {
        HStack(alignment: .top) {
            Button {
                showLyrics = true
            } label: {
                Image(systemName: "quote.bubble")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
                    .opacity(hasLyrics ? 1 : 0.15)
            }
            .disabled(!hasLyrics)
            .accessibilityLabel("Lyrics")

            Spacer()

            VStack(spacing: 16) {
                #if os(iOS)
                    RoutePickerView()
                        .frame(width: 44, height: 44)
                        .scaleEffect(1.35)
                #else
                    Image(systemName: "airplay.audio")
                #endif
                if !systemAudio.routeName.isEmpty {
                    Text(systemAudio.routeName)
                        .font(.caption2.weight(.semibold))
                }
            }

            Spacer()

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Queue")
        }
        .frame(maxWidth: .infinity)
        .font(.title2)
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 80)
        .padding(.top, 5)
    }
}
