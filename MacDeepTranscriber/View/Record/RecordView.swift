//
//  RecordView.swift
//  MacDeepTranscriber
//
//  Created on 20.06.2025.
//

import SwiftUI

struct RecordView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService
    @State private var selectedHistoryTab: Int = 0

    // Default initializer for convenience
    init() {
        self.audioCaptureService = AudioCaptureService()
    }
    
    // Initializer with external service
    init(audioCaptureService: AudioCaptureService) {
        self.audioCaptureService = audioCaptureService
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Language Selection
                LanguageSelectionView(audioCaptureService: audioCaptureService)
                    .padding(.top, 20)
                
                // Transcription output
                TranscriptionOutputView(audioCaptureService: audioCaptureService)

                // History view
                TranscriptionHistoryView(audioCaptureService: audioCaptureService)

                // Controls
                ControlsView(audioCaptureService: audioCaptureService)

                if let error = audioCaptureService.errorMessage {
                    ErrorBannerView(errorMessage: error)
                        .padding(.top)
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal)
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity, minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    audioCaptureService.openRecordingsFolder()
                }) {
                    Image(systemName: "folder")
                        .font(.title2)
                }
                .help("Open Recordings Folder")
            }
        }
    }
}

#Preview {
    RecordView()
}
