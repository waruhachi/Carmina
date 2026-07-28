//
//  LibraryView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct LibraryView: View {
    @ObserveInjection var inject

    @AppStorage("appAccent") private var accent: AppAccent = .red

    @State private var layout = LibraryLayout()
    @State private var isEditing = false

    var body: some View {
        Group {
            if isEditing { editList } else { browse }
        }
        .navigationTitle("Library")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        withAnimation(.smooth(duration: 0.3)) {
                            isEditing = false
                        }
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit Sections", systemImage: "checklist") {
                            withAnimation(.smooth(duration: 0.3)) {
                                isEditing = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                    .accessibilityLabel("More")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsButton()
                }
            }
        }
    }

    private var browse: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(layout.visibleSections) { section in
                    NavigationLink {
                        LibrarySectionPage(section: section)
                    } label: {
                        LibraryRow(section: section, accent: accent.color)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 64)
                }
            }
            .padding(.top, 8)

            RecentlyAddedSection()
                .padding(.top, 24)
                .padding(.bottom, 24)
        }
    }

    private var editList: some View {
        List {
            ForEach(layout.order) { section in
                HStack(spacing: 16) {
                    Button {
                        withAnimation { layout.toggle(section) }
                    } label: {
                        Image(
                            systemName: layout.isVisible(section)
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .font(.title3)
                        .foregroundStyle(
                            layout.isVisible(section)
                                ? accent.color : .secondary
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        layout.isVisible(section)
                            ? "Hide \(section.title)" : "Show \(section.title)"
                    )
                    .accessibilityAddTraits(
                        layout.isVisible(section) ? .isSelected : []
                    )

                    Image(systemName: section.systemImage)
                        .font(.title3)
                        .foregroundStyle(accent.color)
                        .frame(width: 28)

                    Text(section.title).font(.title3)
                }
            }
            .onMove { layout.move(from: $0, to: $1) }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }
}
