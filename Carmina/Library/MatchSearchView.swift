//
//  MatchSearchView.swift
//  Carmina
//
//  Created by waru on 7/31/26.
//

import CarminaMatch
import SwiftUI

struct MatchSearchView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var term: String
    @State private var results: [MatchCandidate] = []
    @State private var isSearching = false
    @State private var searched = false

    let initialTerm: String
    var onSelect: (MatchCandidate) -> Void

    init(initialTerm: String, onSelect: @escaping (MatchCandidate) -> Void) {
        self.initialTerm = initialTerm
        self.onSelect = onSelect
        _term = State(initialValue: initialTerm)
    }

    var body: some View {
        NavigationStack {
            List(results) { candidate in
                Button {
                    onSelect(candidate)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: candidate.artworkURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.secondary.opacity(0.2))
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.title).lineLimit(1)
                            Text(candidate.artist)
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(candidate.album)
                                .font(.caption2).foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .tint(.primary)
            }
            .listStyle(.plain)
            .overlay {
                if isSearching {
                    ProgressView()
                } else if searched && results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search.")
                    )
                }
            }
            .navigationTitle("Find Match")
            .toolbarTitleDisplayMode(.inline)
            .searchable(text: $term)
            .onSubmit(of: .search) { runSearch() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { runSearch() }
        }
    }

    private func runSearch() {
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        Task {
            isSearching = true
            results = await library.searchMatches(query)
            isSearching = false
            searched = true
        }
    }
}
