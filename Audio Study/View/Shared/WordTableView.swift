//
//  WordTableView.swift
//  Audio Study
//
//  Created on 26.06.2025.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct WordTableView: View {
    let title: String
    let words: [String]
    let color: Color
    let icon: String
    @Binding var draggedWord: String?
    let onWordDrop: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок таблицы
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                
                // Export button
                Button(action: exportWords) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(color)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Export word list")
                .disabled(words.isEmpty)
                
                Text("\(words.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .foregroundColor(color)
                    .cornerRadius(6)
            }
            
            Divider()
                .background(color.opacity(0.5))
            
            // Список слов
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(words, id: \.self) { word in
                        Text(word)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(color.opacity(0.1))
                            .foregroundColor(color)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(color.opacity(0.3), lineWidth: 1)
                            )
                            .scaleEffect(draggedWord == word ? 0.95 : 1.0)
                            .opacity(draggedWord == word ? 0.7 : 1.0)
                            .onDrag {
                                draggedWord = word
                                return NSItemProvider(object: word as NSString)
                            }
                            .animation(.easeInOut(duration: 0.2), value: draggedWord)
                    }
                    
                    if words.isEmpty {
                        Text("No words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
        .onDrop(of: [.text], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            
            provider.loadObject(ofClass: NSString.self) { item, error in
                if let word = item as? String {
                    DispatchQueue.main.async {
                        onWordDrop(word)
                        draggedWord = nil
                    }
                }
            }
            return true
        }
    }
    
    // MARK: - Export Functions
    
    private func exportWords() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText, .commaSeparatedText]
        savePanel.nameFieldStringValue = "\(title.replacingOccurrences(of: " ", with: "_"))_words"
        savePanel.message = "Choose location and format to save word list"
        
        // Add accessory view for format selection
        let formatView = NSStackView()
        formatView.orientation = .horizontal
        formatView.spacing = 10
        
        let formatLabel = NSTextField(labelWithString: "Format:")
        let formatPopup = NSPopUpButton()
        formatPopup.addItems(withTitles: ["Plain Text (.txt)", "CSV (.csv)"])
        
        formatView.addArrangedSubview(formatLabel)
        formatView.addArrangedSubview(formatPopup)
        savePanel.accessoryView = formatView
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            let selectedFormat = formatPopup.indexOfSelectedItem
            let content: String
            
            switch selectedFormat {
            case 0: // Plain text
                content = words.joined(separator: "\n")
            case 1: // CSV
                content = "Word\n" + words.map { "\"\($0)\"" }.joined(separator: "\n")
            default:
                content = words.joined(separator: "\n")
            }
            
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                print("Word list exported successfully to \(url.path)")
            } catch {
                print("Failed to export word list: \(error)")
                // Show error alert
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = "Could not save the word list: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}
