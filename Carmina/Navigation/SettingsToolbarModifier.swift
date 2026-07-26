//
//  SettingsToolbarModifier.swift
//  Carmina
//
//  Created by waru on 7/14/26.
//

import SwiftUI

private struct SettingsToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    SettingsButton()
                }
            }
    }
}

extension View {
    func settingsToolbar() -> some View {
        modifier(SettingsToolbarModifier())
    }
}
