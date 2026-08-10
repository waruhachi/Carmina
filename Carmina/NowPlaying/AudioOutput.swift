//
//  AudioOutput.swift
//  Carmina
//
//  Created by waru on 8/10/26.
//

import Foundation

struct AudioOutputPresentation: Equatable {
    let name: String?
    let symbolName: String?

    static let builtIn = AudioOutputPresentation(
        name: nil,
        symbolName: nil
    )

    var displaySymbolName: String { symbolName ?? "airplay.audio" }
}
