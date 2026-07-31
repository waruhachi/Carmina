//
//  ShareURL.swift
//  Carmina
//
//  Created by waru on 7/31/26.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit

    struct ShareURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    struct ShareSheet: UIViewControllerRepresentable {
        let items: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController
        {
            UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )
        }

        func updateUIViewController(
            _ controller: UIActivityViewController,
            context: Context
        ) {}
    }
#endif
