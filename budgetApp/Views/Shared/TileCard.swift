// File: Views/Shared/TileCard.swift
// Reusable tile container. Long-press removed; reorder is controlled externally via a handle.

import SwiftUI

struct TileCard<Content: View>: View {
    var size: CGSize
    var cornerRadius: CGFloat = 16
    var editing: Bool = false
    /// When true, the tile performs a subtle jiggle animation (for edit mode).
    var wiggle: Bool = false
    var background: Color = .cardBackground
    var overlayStroke: Color = .subtleOutline
    var content: () -> Content
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(overlayStroke.opacity(editing ? 0.9 : 1.0), lineWidth: editing ? 1.5 : 1)
                )
                .rotationEffect(.degrees(editing && wiggle ? 1.2 : 0))
                .scaleEffect(editing && wiggle ? 1.01 : 1.0)
                .animation(editing ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true) : .default, value: wiggle)
            content()
                .padding(14)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
