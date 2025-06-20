//
//  LearnWordsView.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import SwiftUI

struct LearnWordsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Learn Words")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This feature is coming soon!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Here you'll be able to learn new words and expand your vocabulary.")
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
    LearnWordsView()
}
