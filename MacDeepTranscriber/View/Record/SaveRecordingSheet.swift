import SwiftUI

struct SaveRecordingSheet: View {
    @Binding var isPresented: Bool
    @State private var recordingTitle: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    let onSave: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Save Recording")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Enter a title for this recording session")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Recording Title")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Enter title...", text: $recordingTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        saveIfValid()
                    }
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    saveIfValid()
                }
                .buttonStyle(.borderedProminent)
                .disabled(recordingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(32)
        .frame(width: 400, height: 300)
        .onAppear {
            // Generate default title with timestamp
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            recordingTitle = "Recording \(formatter.string(from: Date()))"
            
            // Focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func saveIfValid() {
        let title = recordingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        
        onSave(title)
        isPresented = false
    }
}

#Preview {
    SaveRecordingSheet(isPresented: .constant(true)) { title in
        print("Saving recording with title: \(title)")
    }
}
