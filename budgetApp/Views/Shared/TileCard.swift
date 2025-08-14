// ===== FILE: BudgetApp/Views/Shared/TileCard.swift =====
// Make the pulsing dashed/solid border the DEFAULT behavior whenever `editing == true`.
// This way BOTH Budget tiles and Credit Card tiles get it automatically, with code defined once.

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
    /// When true, the background will pulse between a light gray and white while editing.
    var pulseBackgroundWhenEditing: Bool = false
    var content: () -> Content

    @State private var dashedVisible: Bool = false
    @State private var bgPulse: Bool = false

    private var showPulse: Bool { editing && dashedWhenEditing }
    private var showBgPulse: Bool { editing && pulseBackgroundWhenEditing }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)

            if showBgPulse {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.gray.opacity(bgPulse ? 0.0 : 0.2))
            }

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
            .animation(.easeInOut(duration: 0.9), value: dashedVisible)

            // Content
            content()
                .padding(14)
        }
        .onAppear {
            handlePulseChange(active: showPulse)
            handleBgPulseChange(active: showBgPulse)
        }
        .onChange(of: showPulse) { active in handlePulseChange(active: active) }
        .onChange(of: showBgPulse) { active in handleBgPulseChange(active: active) }
        .frame(width: size.width, height: size.height)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func handlePulseChange(active: Bool) {
        if active {
            dashedVisible = false
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dashedVisible = true
                }
            }
        } else {
            dashedVisible = false
        }
    }

    private func handleBgPulseChange(active: Bool) {
        if active {
            bgPulse = false
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    bgPulse = true
                }
            }
        } else {
            bgPulse = false
        }
    }
}
