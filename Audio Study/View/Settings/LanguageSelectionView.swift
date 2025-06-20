import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject var audioCaptureService: AudioCaptureService

    var body: some View {
        VStack(spacing: 12) {
            Text("Language Settings")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 20) {
                // Task selection (left side) - only show when WhisperKit is active
                if audioCaptureService.selectedSpeechEngines.contains(.whisperKit) {
                    VStack(alignment: .leading, spacing: 6) {
                        
                        HStack {
                            Text("Task")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("(Whisperkit only)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Picker(
                            "Task",
                            selection: $audioCaptureService.whisperTaskType
                        ) {
                            ForEach(WhisperTaskType.allCases, id: \.self) { taskType in
                                Text(taskType.displayName)
                                    .tag(taskType)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .disabled(audioCaptureService.isCapturing)
                        .onChange(of: audioCaptureService.whisperTaskType) { newTaskType in
                            audioCaptureService.updateWhisperTaskType(newTaskType)
                        }
                        .frame(width: 180)
                    }
                }
                
                // Language selection (unified for both engines)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Language")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        // Show which engines are using this language
                        if audioCaptureService.selectedSpeechEngines.count > 1 {
                            Text("(Shared)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Picker(
                        "Language",
                        selection: $audioCaptureService.whisperSelectedLanguage
                    ) {
                        ForEach(audioCaptureService.getSupportedWhisperLanguages(), id: \.0) { code, name in
                            Text(name)
                                .tag(code)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .disabled(audioCaptureService.isCapturing)
                    .onChange(of: audioCaptureService.whisperSelectedLanguage) { newLanguage in
                        // Update both engines when language changes
                        audioCaptureService.updateWhisperLanguage(newLanguage)
                    }
                    .frame(minWidth: 220)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .opacity(0.5)
        )
        .padding(.horizontal)
    }
}

#Preview {
    LanguageSelectionView(audioCaptureService: AudioCaptureService())
}
