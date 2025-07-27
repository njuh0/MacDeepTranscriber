import Foundation
import AVFoundation

/// Application-wide error types
enum AppError: Error, LocalizedError {
    case microphonePermissionDenied
    case engineStartError(String)
    case deviceNotAvailable
    case coreAudioError(Int, String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access denied. Please enable microphone access in Settings."
        case .engineStartError(let message):
            return "Audio engine error: \(message)"
        case .deviceNotAvailable:
            return "Audio device not available. Please check your audio input settings and ensure BlackHole is properly configured."
        case .coreAudioError(let code, let message):
            return "Audio system error (\(code)): \(message)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
    
    static func fromCoreAudioError(_ error: Error) -> AppError {
        let nsError = error as NSError
        if nsError.domain == NSOSStatusErrorDomain {
            let errorMessage: String
            
            switch nsError.code {
            case -10877: // kAudioHardwareNotRunningError
                errorMessage = "Audio device not running or available"
                return .deviceNotAvailable
            case -10875: // kAudioHardwareUnspecifiedError
                errorMessage = "Unspecified hardware error"
            case -10851: // kAudioHardwareUnsupportedOperationError
                errorMessage = "Unsupported audio operation"
            default:
                errorMessage = "Core Audio error"
            }
            
            return .coreAudioError(nsError.code, errorMessage)
        } else {
            return .unknownError(error.localizedDescription)
        }
    }
}
