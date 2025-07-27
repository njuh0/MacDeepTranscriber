import Foundation

// MARK: - Transcription Entry Model
struct TranscriptionEntry: Codable, Identifiable {
    let id: UUID
    let date: String
    let transcription: String

    // Initialize with a Date object, which will be formatted to a string
    init(id: UUID = UUID(), date: Date, transcription: String) {
        self.id = id
        self.date = DateUtil.iso8601Formatter.string(from: date)
        self.transcription = transcription
    }

    // If you need to initialize from a pre-formatted date string (e.g., when decoding)
    // Codable will use this automatically if keys match.
    // If not, you might need custom init(from decoder: Decoder)
}

// MARK: - Date Utility
enum DateUtil {
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // Standard ISO8601 format
        return formatter
    }()

    static func getCurrentFormattedDate() -> String {
        return iso8601Formatter.string(from: Date())
    }
}

// MARK: - Recording Metadata Model
struct RecordingMetadata: Codable {
    let title: String
    let date: Date
    let appleSpeechEnabled: Bool
    let appleSpeechLocale: String
    let copiedFiles: [String]
    let appleSpeechTranscriptions: [TranscriptionEntry]
    let totalTranscriptions: Int
}
