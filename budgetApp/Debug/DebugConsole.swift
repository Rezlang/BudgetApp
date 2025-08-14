// File: BudgetApp/Debug/DebugConsole.swift
// Full-screen expandable console for ChatGPT diagnostics.

import SwiftUI
import UIKit

struct DebugConsoleView: View {
    var title: String = "Debug Console"
    @Binding var lines: [String]
    @State private var isPresented: Bool = false

    private var combined: String {
        lines.joined(separator: "\n")
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("ChatGPT Debug Output", systemImage: "ladybug")
                .font(.footnote)
                .padding(6)
                .background(Capsule().fill(Color.gray.opacity(0.2)))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $isPresented) {
            NavigationStack {
                ScrollView {
                    Text(combined.isEmpty ? "— no logs yet —" : combined)
                        .textSelection(.enabled)
                        .font(.footnote.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 20) {
                            Button("Copy") {
                                UIPasteboard.general.string = combined
                            }
                            Button("Clear") {
                                lines.removeAll()
                            }
                        }
                        .font(.footnote)
                    }
                }
            }
        }
    }
}

extension Font {
    static func footnoteMonospaced() -> Font {
        .footnote.monospaced()
    }
}
