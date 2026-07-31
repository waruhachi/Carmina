//
//  MatchScorerTests.swift
//  CarminaKit
//
//  Created by waru on 7/30/26.
//

import Foundation
import Testing

@testable import CarminaMatch

@Suite struct MatchScorerTests {
    @Test func exactMatchScoresHigh() {
        let c = MatchCandidate(
            id: 1,
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "A Night at the Opera",
            durationSeconds: 355,
            artworkURL: nil
        )
        let q = MetadataQuery(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            durationSeconds: 354
        )
        #expect(MatchScorer.confidence(for: c, query: q) > 0.9)
    }

    @Test func wrongDurationLowersScore() {
        let c = MatchCandidate(
            id: 1,
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "",
            durationSeconds: 420,
            artworkURL: nil
        )
        let q = MetadataQuery(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            durationSeconds: 354
        )
        #expect(MatchScorer.confidence(for: c, query: q) < 0.9)
    }

    @Test func differentSongScoresLow() {
        let c = MatchCandidate(
            id: 1,
            title: "Radio Ga Ga",
            artist: "Queen",
            album: "",
            durationSeconds: 200,
            artworkURL: nil
        )
        let q = MetadataQuery(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            durationSeconds: 354
        )
        #expect(MatchScorer.confidence(for: c, query: q) < 0.6)
    }

    @Test func emptyArtistStillMatchesOnTitleAndDuration() {
        let c = MatchCandidate(
            id: 1,
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "",
            durationSeconds: 355,
            artworkURL: nil
        )
        let q = MetadataQuery(
            title: "bohemian rhapsody queen",
            artist: "",
            durationSeconds: 355
        )
        #expect(MatchScorer.confidence(for: c, query: q) >= 0.75)
    }
}

@Suite struct ITunesSearchClientTests {
    @Test func decodesAndUpscalesArtwork() async throws {
        let json = """
            {"resultCount":1,"results":[{
              "trackId":123,"trackName":"Bohemian Rhapsody","artistName":"Queen",
              "collectionName":"A Night at the Opera","trackTimeMillis":354947,
              "artworkUrl100":"https://example.com/a/100x100bb.jpg"}]}
            """
        MockURLProtocol.stubData = Data(json.utf8)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = ITunesSearchClient(
            session: URLSession(configuration: config)
        )

        let results = try await client.search(term: "queen bohemian rhapsody")
        #expect(results.count == 1)
        #expect(results[0].title == "Bohemian Rhapsody")
        #expect(results[0].durationSeconds == 354.947)
        #expect(
            results[0].artworkURL?.absoluteString.contains("600x600bb") == true
        )
    }
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var stubData: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest
    {
        request
    }
    override func startLoading() {
        if let data = MockURLProtocol.stubData {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
