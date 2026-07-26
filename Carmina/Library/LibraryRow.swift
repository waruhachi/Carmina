//
//  LibraryRow.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct LibraryRow: View {
    @ObserveInjection var inject

    let section: LibrarySection
    let accent: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: section.systemImage)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 28)
            Text(section.title)
                .font(.title3)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .contentShape(.rect)
    }
}
