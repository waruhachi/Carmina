//
//  NowPlayingBackground.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct NowPlayingBackground: View {
    var colors: [Color]

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                .init(0, 1), .init(0.5, 1), .init(1, 1),
            ],
            colors: meshColors
        )
        .overlay(.black.opacity(0.2))
        .ignoresSafeArea()
    }

    private var meshColors: [Color] {
        let base = colors.isEmpty ? [.indigo, .purple, .pink] : colors
        return (0..<9).map { base[$0 % base.count] }
    }
}
