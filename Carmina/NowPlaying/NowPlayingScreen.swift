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

    @Environment(PlayerCoordinator.self) private var player
    @Environment(DeviceLibrary.self) private var library

    @State private var systemAudio = SystemAudio()
    @State private var artImage: Image?
    @State private var palette: [Color] = []
    @State private var minVolumeTrigger = false
    @State private var maxVolumeTrigger = false
    @State private var showLyrics = false
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

    var body: some View {
        ZStack(alignment: .top) {
            background
            coverLayer
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                controls
                    .padding(.horizontal, 28)
                    .padding(.bottom, -5)
            }
            grip
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
        .task(id: player.current?.id) { await refreshArtwork() }
        .sheet(isPresented: $showLyrics) {
            LyricsView(
                title: player.current?.title ?? "",
                lyrics: player.current?.lyrics ?? ""
            )
        }
    }

    private func refreshArtwork() async {
        guard let song = player.current else {
            artImage = nil
            palette = []
            return
        }
        #if canImport(MediaPlayer)
            artImage = library.artworkImage(
                for: song.persistentID,
                size: CGSize(width: 1000, height: 1000)
            )
            if let ui = library.artworkUIImage(
                for: song.persistentID,
                size: CGSize(width: 300, height: 300)
            ),
                let colors = ui.dominantColorFrequencies()?
                    .map({ Color($0.color) }),
                !colors.isEmpty
            {
                palette = colors
            }
        #endif
    }

    private var hasLyrics: Bool {
        !(player.current?.lyrics?.isEmpty ?? true)
    }
}

extension NowPlayingScreen {
    fileprivate var grip: some View {
        Capsule().fill(.white.opacity(0.5)).frame(width: 60, height: 4)
            .padding(.top, 8)
    }

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
                        .init(color: .black.opacity(0.55), location: 0.80),
                        .init(color: .black.opacity(0.55), location: 1.0),
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

    fileprivate var controls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(player.current?.title ?? "")
                        .font(.title3.weight(.semibold))
                        .id(player.current?.title ?? "")
                    MarqueeText(player.current?.artist ?? "")
                        .foregroundStyle(.white.opacity(0.7))
                        .id(player.current?.artist ?? "")
                }
                Spacer(minLength: 8)
                if let song = player.current {
                    Menu {
                        SongMenu(song: song)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .contentShape(.rect)
                    }
                    .tint(.primary)
                }
            }

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
            .padding(.top, 15)

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
                        player.previous()
                    }
                )
                PlayerButton(
                    label: {
                        PlayerButtonLabel(
                            type: player.isPlaying ? .pause : .play,
                            size: 34
                        )
                    },
                    onEnded: { player.togglePlayPause() }
                )
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
                        player.next()
                    }
                )
            }
            .playerButtonStyle(
                .init(
                    size: 68,
                    labelColor: .white,
                    tint: .white.opacity(0.2),
                    pressedColor: .white
                )
            )
            .padding(.top, 20)

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
            .font(.system(size: 14))
            .frame(height: 50)
            .padding(.horizontal, -10)
            .onChange(of: systemAudio.volume) {
                if systemAudio.volume == 0 { minVolumeTrigger.toggle() }
                if systemAudio.volume == 1 { maxVolumeTrigger.toggle() }
            }
            .padding(.top, 35)

            footer
        }
    }

    fileprivate var footer: some View {
        HStack(alignment: .top) {
            Button {
                showLyrics = true
            } label: {
                Image(systemName: "quote.bubble")
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
                    .opacity(hasLyrics ? 1 : 0.15)
            }
            .disabled(!hasLyrics)

            Spacer()

            VStack(spacing: 16) {
                #if os(iOS)
                    RoutePickerView()
                        .frame(width: 30, height: 30)
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
            } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
        }
        .frame(maxWidth: .infinity)
        .font(.title2)
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 80)
        .padding(.top, 15)
    }
}
