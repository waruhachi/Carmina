//
//  ColorfulBackground.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct ColorfulBackground: View {
    @ObserveInjection var inject

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model = ColorfulBackgroundModel.shared

    let colors: [Color]

    var body: some View {
        MulticolorGradient(
            points: model.points,
            animationUpdateHandler: { newPoints in
                model.onUpdate(animatedData: newPoints)
            }
        )
        .onAppear {
            model.set(colors)
            model.onAppear(reduceMotion: reduceMotion)
        }
        .onChange(of: colors) {
            model.set(colors)
        }
        .onDisappear {
            model.onDisappear()
        }
    }
}
