//
//  MatchScorer.swift
//  CarminaKit
//
//  Created by waru on 7/30/26.
//

import Foundation

public enum MatchScorer {
    public static func scored(
        _ candidates: [MatchCandidate],
        for query: MetadataQuery
    ) -> [MatchCandidate] {
        candidates
            .map { c in
                var c = c
                c.confidence = confidence(for: c, query: query)
                return c
            }
            .sorted { $0.confidence > $1.confidence }
    }

    public static func best(
        _ candidates: [MatchCandidate],
        for query: MetadataQuery
    ) -> MatchCandidate? {
        scored(candidates, for: query).first
    }

    static func confidence(
        for c: MatchCandidate,
        query: MetadataQuery
    ) -> Double {
        let titleScore = similarity(c.title, query.title)
        let durScore = durationScore(c, query)
        if query.artist.isEmpty {
            return titleScore * 0.65 + durScore * 0.35
        }
        let artistScore = similarity(c.artist, query.artist)
        return titleScore * 0.5 + artistScore * 0.3 + durScore * 0.2
    }

    static func durationScore(
        _ c: MatchCandidate,
        _ query: MetadataQuery
    ) -> Double {
        guard let a = c.durationSeconds, let b = query.durationSeconds else {
            return 0.5
        }
        let diff = abs(a - b)
        if diff <= 2 { return 1 }
        if diff >= 12 { return 0 }
        return 1 - (diff - 2) / 10
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        let x = normalize(a)
        let y = normalize(b)
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        if x == y { return 1 }
        let xt = Set(x.split(separator: " "))
        let yt = Set(y.split(separator: " "))
        let union = xt.union(yt).count
        let jaccard =
            union == 0 ? 0 : Double(xt.intersection(yt).count) / Double(union)
        let bonus = (x.contains(y) || y.contains(x)) ? 0.3 : 0.0
        return min(1, jaccard + bonus)
    }

    static func normalize(_ s: String) -> String {
        let lowered = s.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filtered = String(
            lowered.unicodeScalars.filter { allowed.contains($0) }
        )
        return filtered.split(separator: " ").joined(separator: " ")
    }
}
