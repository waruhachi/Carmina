//
//  MulticolorGradient.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct MulticolorGradient: View, Animatable {
    @ObserveInjection var inject

    var points: ColorPoints
    var animationUpdateHandler: ((ColorPoints) -> Void)?

    var uniforms: Uniforms {
        Uniforms(
            params: GradientParams(
                points: points,
                bias: 0.05,
                power: 2.5,
                noise: 2
            )
        )
    }

    var animatableData: ColorPoints.AnimatableData {
        get { points.animatableData }
        set {
            points = ColorPoints(newValue)
            animationUpdateHandler?(points)
        }
    }

    var body: some View {
        Rectangle()
            .colorEffect(
                ShaderLibrary.gradient(.boundingRect, .uniforms(uniforms))
            )
    }
}

@MainActor
extension MulticolorGradient {
    fileprivate mutating func updatePoints(newPoints: ColorPoints) {
        points = newPoints
        animationUpdateHandler?(newPoints)
    }
}

extension Shader.Argument {
    static func uniforms(_ param: Uniforms) -> Shader.Argument {
        var copy = param
        return .data(Data(bytes: &copy, count: MemoryLayout<Uniforms>.stride))
    }
}
