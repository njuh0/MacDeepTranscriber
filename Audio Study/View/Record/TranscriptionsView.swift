//
//  TranscriptionsView.swift
//  Audio Study
//
//  Created on 21.06.2025.
//

import SwiftUI

struct TranscriptionsView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Transcriptions")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("This is your transcriptions page")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Placeholder content
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Your transcriptions will appear here")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Start recording to see your transcriptions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    TranscriptionsView(audioCaptureService: AudioCaptureService())
}
