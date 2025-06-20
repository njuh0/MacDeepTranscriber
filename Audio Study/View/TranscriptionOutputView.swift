import SwiftUI

struct TranscriptionOutputView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
        VStack(spacing: 10) {
            // No engines selected message
            if audioCaptureService.selectedSpeechEngines.isEmpty {
                Text("No speech engines selected")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            } else {
                // Horizontal layout for both outputs
                HStack(spacing: 10) {
                    // WhisperKit Output (in its own scrollable container)
                    if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("WhisperKit Output:")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.horizontal)

                        ScrollViewReader { whisperProxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 4) {
                                    if audioCaptureService.recognizedText.isEmpty {
                                        Text("WhisperKit transcription will appear here...")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                    } else {
                                        Text(audioCaptureService.recognizedText)
                                            .font(.title3)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .foregroundColor(.primary)
                                            .textSelection(.enabled)
                                            .padding()
                                            .id("transcriptionText")
                                    }
                                }
                            }
                            .onChange(of: audioCaptureService.recognizedText) { _ in
                                // Auto-scroll to bottom when new text is added
                                if !audioCaptureService.recognizedText.isEmpty {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        whisperProxy.scrollTo("transcriptionText", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }

                // Apple Speech Output (in its own scrollable container)
                if audioCaptureService.selectedSpeechEngines.contains(.appleSpeech) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Apple Speech Output:")
                                .font(.headline)
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.horizontal)

                        ScrollViewReader { appleProxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 4) {
                                    if audioCaptureService.appleSpeechText.isEmpty {
                                        Text("Apple Speech transcription will appear here...")
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                    } else {
                                        Text(audioCaptureService.appleSpeechText)
                                            .font(.title3)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .foregroundColor(.primary)
                                            .textSelection(.enabled)
                                            .padding()
                                            .id("appleSpeechText")
                                    }
                                }
                            }
                            .onChange(of: audioCaptureService.appleSpeechText) { _ in
                                // Auto-scroll to bottom when new text is added
                                if !audioCaptureService.appleSpeechText.isEmpty {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        appleProxy.scrollTo("appleSpeechText", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: 1)
                    )
                }
                } // Close HStack
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}
