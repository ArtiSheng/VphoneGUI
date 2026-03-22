//
//  TerminalView.swift
//  VphoneGUI
//
//  Created by ArtiSheng on 2026/3/22.
//

import SwiftUI

struct TerminalView: View {
    let title: String
    let icon: String
    @Bindable var manager: ProcessManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                // Status indicator
                Circle()
                    .fill(manager.isRunning ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .shadow(color: manager.isRunning ? .green.opacity(0.6) : .clear, radius: 4)

                Text(manager.statusText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(manager.isRunning ? .green : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: NSColor(white: 0.15, alpha: 1)))

            Divider().background(Color.green.opacity(0.3))

            // Terminal output
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Text(manager.output.isEmpty ? "等待启动..." : manager.output)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(manager.output.isEmpty ? .gray : .green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                        .id("bottom")
                }
                .onChange(of: manager.output) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(nsColor: NSColor(white: 0.08, alpha: 1)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(manager.isRunning ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
