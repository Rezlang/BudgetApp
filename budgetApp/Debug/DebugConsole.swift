// File: Debug/DebugConsole.swift
// Collapsible on-screen console for temporary diagnostics.

import SwiftUI
import UIKit

struct DebugConsoleView: View {
    var title: String = "Debug Console"
    @Binding var lines: [String]
    @State private var isExpanded: Bool = true

    private var combined: String {
        lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 8) {
            DisclosureGroup(isExpanded ? "\(title) (tap to hide)" : "\(title) (tap to show)", isExpanded: $isExpanded) {
                ScrollView {
                    Text(combined.isEmpty ? "— no logs yet —" : combined)
                        .textSelection(.enabled)
                        .font(.footnote.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .frame(minHeight: 100, maxHeight: 220)
                HStack(spacing: 12) {
                    Button("Copy") {
                        UIPasteboard.general.string = combined
                    }
                    Button("Clear") {
                        lines.removeAll()
                    }
                    Spacer()
                }
                .font(.footnote)
                .padding(.top, 4)
            }
            .font(.headline)
            .tint(.purple)
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }
}

extension Font {
    static func footnoteMonospaced() -> Font {
        .footnote.monospaced()
    }
}
