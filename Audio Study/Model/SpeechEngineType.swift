import Foundation

enum SpeechEngineType: String, CaseIterable, Identifiable {
    case appleSpeech = "Apple Speech"
    case whisperKit = "WhisperKit"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .appleSpeech:
            return "Native Apple Speech Recognition"
        case .whisperKit:
            return "OpenAI Whisper (Local)"
        }
    }
    
    var isOnDevice: Bool {
        switch self {
        case .appleSpeech, .whisperKit:
            return true
        }
    }
    
    var supportsMultipleLanguages: Bool {
        switch self {
        case .appleSpeech:
            return true
        case .whisperKit:
            return true
        }
    }
}
