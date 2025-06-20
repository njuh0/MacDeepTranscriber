//
//  AIChatView.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import SwiftUI

struct AIChatView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("AI Chat")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This feature is coming soon!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Here you'll be able to chat with AI to practice your language skills.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    AIChatView()
}
