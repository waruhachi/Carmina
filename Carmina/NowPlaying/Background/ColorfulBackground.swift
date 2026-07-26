//
//  ColorfulBackground.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct ColorfulBackground: View {
    @ObserveInjection var inject

    @State var model = ColorfulBackgroundModel()

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
            model.onAppear()
        }
        .onChange(of: colors) {
            model.set(colors)
        }
    }
}
