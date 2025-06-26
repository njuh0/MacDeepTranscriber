//
//  InstantTooltipView.swift
//  Audio Study
//
//  Created on 26.06.2025.
//

import SwiftUI

struct InstantTooltipView<Content: View>: View {
    let content: () -> Content
    let tooltip: String
    
    @State private var isHovered = false
    @State private var showTooltip = false
    
    var body: some View {
        content()
            .onHover { hovering in
                if hovering {
                    showTooltip = true
                } else {
                    showTooltip = false
                }
                isHovered = hovering
            }
            .overlay(
                Group {
                    if showTooltip {
                        Text(tooltip)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .foregroundColor(.primary)
                            .cornerRadius(6)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .offset(x: 0, y: -35)
                            .zIndex(1000)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .animation(.easeInOut(duration: 0.1), value: showTooltip)
            )
    }
}

#Preview {
    InstantTooltipView(
        content: {
            Image(systemName: "questionmark.circle")
                .font(.title)
        },
        tooltip: "This is an instant tooltip!"
    )
    .padding(50)
}
