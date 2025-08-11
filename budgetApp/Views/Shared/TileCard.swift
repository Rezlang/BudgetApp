// ===== FILE: BudgetApp/Views/Shared/TileCard.swift =====
// Reusable tile container. In move mode: solid background and a pulsing border
// that crossfades between solid and dashed. No jiggle.

import SwiftUI

struct TileCard<Content: View>: View {
    var size: CGSize
    var cornerRadius: CGFloat = 16
    var editing: Bool = false
    /// Kept for API compatibility; ignored (no jiggle).
    var wiggle: Bool = false
    var background: Color = .cardBackground
    /// Base stroke color.
    var overlayStroke: Color = .subtleOutline
    /// When true, the border will pulse between dashed and solid while `editing` is true.
    var dashedWhenEditing: Bool = false
    var content: () -> Content

    @State private var dashedVisible: Bool = false

    private var showPulse: Bool { editing && dashedWhenEditing }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)

            // Border: crossfade between solid and dashed
            ZStack {
                let solidOpacity: Double = showPulse ? (dashedVisible ? 0.0 : 1.0) : 1.0
                let dashedOpacity: Double = showPulse ? (dashedVisible ? 1.0 : 0.0) : 0.0

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(overlayStroke.opacity(editing ? 0.9 : 1.0),
                            lineWidth: editing ? 1.5 : 1)
                    .opacity(solidOpacity)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(overlayStroke.opacity(0.9),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    .opacity(dashedOpacity)
            }
            // Smooth, slightly slower pulse
            .animation(.easeInOut(duration: 0.9), value: dashedVisible)

            // Content
            content()
                .padding(14)
        }
        .onAppear { handlePulseChange(active: showPulse) }
        .onChange(of: showPulse) { active in handlePulseChange(active: active) }
        .frame(width: size.width, height: size.height)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func handlePulseChange(active: Bool) {
        if active {
            dashedVisible = false
            // Start continuous pulse (solid <-> dashed)
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dashedVisible = true
                }
            }
        } else {
            // Stop pulsing, show solid
            dashedVisible = false
        }
    }
}
