//
//  RecordView.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import SwiftUI

struct RecordView: View {
    @StateObject private var audioCaptureService = AudioCaptureService()
    @State private var selectedHistoryTab: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SpeechEngineSelectionView(audioCaptureService: audioCaptureService)
                    .padding(.top, 20)

                // Unified Language Selection (shown when any engine is selected)
                if !audioCaptureService.selectedSpeechEngines.isEmpty {
                    LanguageSelectionView(audioCaptureService: audioCaptureService)
                }

                // Conditional rendering for settings views
                if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                    WhisperKitSettingsView(audioCaptureService: audioCaptureService)
                }
                
                // Only show transcription output when engines are selected
                if !audioCaptureService.selectedSpeechEngines.isEmpty {
                    TranscriptionOutputView(audioCaptureService: audioCaptureService)
                }

                // Conditional rendering for history view
                if !audioCaptureService.selectedSpeechEngines.isEmpty {
                    TranscriptionHistoryView(audioCaptureService: audioCaptureService, selectedHistoryTab: $selectedHistoryTab)
                }

                // Only show controls when engines are selected
                if !audioCaptureService.selectedSpeechEngines.isEmpty {
                    ControlsView(audioCaptureService: audioCaptureService)
                }

                if let error = audioCaptureService.errorMessage {
                    ErrorBannerView(errorMessage: error)
                        .padding(.top)
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal)
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity, minHeight: 600, idealHeight: 800, maxHeight: .infinity)
    }
}

#Preview {
    RecordView()
}
