//
//  TranscriptionPersistenceService.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import Foundation

/// Service responsible for persisting transcription history to JSON files
class TranscriptionPersistenceService {
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Saves the combined transcription history to a JSON file
    /// This includes transcriptions from all speech engines
    func saveCombinedTranscriptionHistory(_ transcriptions: [TranscriptionEntry]) {
        let fileURL = getDocumentsDirectory().appendingPathComponent("combined_transcription_history.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(transcriptions)
            try data.write(to: fileURL, options: [.atomicWrite])
            print("✅ Successfully saved combined transcription history to \(fileURL.path)")
            print("📊 Total transcriptions saved: \(transcriptions.count)")
        } catch {
            print("❌ Error saving combined transcription history to JSON: \(error.localizedDescription)")
        }
    }
    
    /// Loads the combined transcription history from a JSON file
    func loadCombinedTranscriptionHistory() -> [TranscriptionEntry] {
        let fileURL = getDocumentsDirectory().appendingPathComponent("combined_transcription_history.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ℹ️ Combined transcription history JSON file does not exist. Starting with empty history.")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let transcriptions = try decoder.decode([TranscriptionEntry].self, from: data)
            print("✅ Successfully loaded combined transcription history from JSON. Count: \(transcriptions.count)")
            return transcriptions
        } catch {
            print("❌ Error loading combined transcription history from JSON: \(error.localizedDescription). Starting with empty history.")
            return []
        }
    }
    
    /// Appends new transcriptions to the existing history and saves to JSON
    func appendAndSaveTranscriptions(_ newTranscriptions: [TranscriptionEntry]) {
        let existingHistory = loadCombinedTranscriptionHistory()
        let updatedHistory = existingHistory + newTranscriptions
        saveCombinedTranscriptionHistory(updatedHistory)
    }
    
    /// Clears the combined transcription history file
    func clearCombinedTranscriptionHistory() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("combined_transcription_history.json")
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ Successfully cleared combined transcription history")
            }
        } catch {
            print("❌ Error clearing combined transcription history: \(error.localizedDescription)")
        }
    }
    
    /// Gets the file URL for the combined transcription history for external access
    func getCombinedTranscriptionHistoryURL() -> URL {
        return getDocumentsDirectory().appendingPathComponent("combined_transcription_history.json")
    }
}
