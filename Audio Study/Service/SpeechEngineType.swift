import Foundation

enum SpeechEngineType: String, CaseIterable {
    case appleSpeech = "Apple Speech Recognition"
    case whisperKit = "WhisperKit"
    
    var description: String {
        switch self {
        case .appleSpeech:
            return "Real-time recognition using Apple's built-in Speech framework"
        case .whisperKit:
            return "High-quality offline recognition using WhisperKit (native Swift)"
        }
    }
    
    var isRealTime: Bool {
        switch self {
        case .appleSpeech:
            return true
        case .whisperKit:
            return false
        }
    }
    
    var requiresInternet: Bool {
        switch self {
        case .appleSpeech:
            return true // Apple Speech может требовать интернет для некоторых языков
        case .whisperKit:
            return false // Полностью локальный после загрузки модели
        }
    }
    
}
