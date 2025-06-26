//
//  WordTableView.swift
//  Audio Study
//
//  Created on 26.06.2025.
//

import SwiftUI

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
}
