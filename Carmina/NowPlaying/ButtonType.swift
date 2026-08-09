//
//  ButtonType.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

enum ButtonType {
    case play, stop, pause, backward, forward
}

enum PlayerButtonTrigger: Equatable {
    case one(bouncing: Bool)
    case another(bouncing: Bool)
}

struct PlayerButtonLabel: View {
    let type: ButtonType
    let size: CGFloat
    var animationTrigger: PlayerButtonTrigger

    init(
        type: ButtonType,
        size: CGFloat,
        animationTrigger: PlayerButtonTrigger? = nil
    ) {
        self.type = type
        self.size = size
        self.animationTrigger = animationTrigger ?? .one(bouncing: false)
    }

    var body: some View {
        switch type {
        case .forward:
            AnimatedForwardLabel(size: size, trigger: animationTrigger)
        case .backward:
            AnimatedForwardLabel(size: size, trigger: animationTrigger)
                .scaleEffect(x: -1)
        default:
            Image(systemName: type.systemImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .offset(x: type == .play ? size * 0.10 : 0)
        }
    }
}

extension PlayerButtonTrigger {
    mutating func toggle(bouncing: Bool) {
        switch self {
        case .one: self = .another(bouncing: bouncing)
        case .another: self = .one(bouncing: bouncing)
        }
    }
}

extension ButtonType {
    var systemImageName: String {
        switch self {
        case .play: "play.fill"
        case .stop: "stop.fill"
        case .pause: "pause.fill"
        case .backward: "backward.fill"
        case .forward: "forward.fill"
        }
    }
}
