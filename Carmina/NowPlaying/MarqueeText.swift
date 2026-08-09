//
//  MarqueeText.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct MarqueeText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var textSize: CGSize = .zero
    @State private var animate = false

    let text: String
    var startDelay: Double = 1.0
    var leftFade: CGFloat = 12
    var rightFade: CGFloat = 12
    var spacing: CGFloat = 80

    init(_ text: String) { self.text = text }

    var body: some View {
        GeometryReader { geo in
            let viewWidth = geo.size.width
            let scrolls = textSize.width > viewWidth && !reduceMotion

            ZStack {
                animatedText(viewWidth: viewWidth).opacity(scrolls ? 1 : 0)
                staticText.opacity(scrolls ? 0 : 1)
            }
        }
        .frame(height: textSize.height)
        .overlay {
            Text(text)
                .padding(.leading, leftFade)
                .padding(.trailing, rightFade)
                .lineLimit(1)
                .fixedSize()
                .onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: {
                    textSize = $0
                }
                .hidden()
        }
        .onChange(of: textSize) {
            guard !animate, textSize.width > 0, !reduceMotion else { return }
            withAnimation(marqueeAnimation) { animate = true }
        }
    }

    private var lineWidth: CGFloat {
        textSize.width - (leftFade + rightFade) + spacing
    }
    private var offset: CGFloat { animate ? lineWidth : 0 }

    private func animatedText(viewWidth: CGFloat) -> some View {
        Group {
            Text(text).offset(x: -offset)
            Text(text).offset(x: -offset + lineWidth)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .frame(width: viewWidth)
        .offset(x: leftFade)
        .mask(fadeMask)
    }

    private var staticText: some View {
        Text(text)
            .padding(.leading, leftFade)
            .padding(.trailing, rightFade)
            .lineLimit(1)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var marqueeAnimation: Animation {
        .linear(duration: Double(textSize.width) / 30)
            .delay(startDelay)
            .repeatForever(autoreverses: false)
    }

    private var fadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: leftFade)
            Color.black
            LinearGradient(
                colors: [.black, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: rightFade)
        }
    }
}
