import Foundation

enum SpeechEngineType: String, CaseIterable, Identifiable {
    case appleSpeech = "Apple Speech"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .appleSpeech:
            return "Native Apple Speech Recognition"
        }
    }
    
    var isOnDevice: Bool {
        switch self {
        case .appleSpeech:
            return true
        }
    }
    
    var supportsMultipleLanguages: Bool {
        switch self {
        case .appleSpeech:
            return true
        }
    }
}
