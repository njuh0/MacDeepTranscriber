
//
//  AIChatRightSidebarView.swift
//  Audio Study
//
//  Created on 26.06.2025.
//

import SwiftUI

struct AIChatRightSidebarView: View {
    let recordingsFolders: [String]
    @Binding var selectedFolders: Set<String>
    let enhancedFolders: [String: Bool]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !recordingsFolders.isEmpty {
                Divider()

                Text("Recordings")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 10)

                List(recordingsFolders, id: \.self) { folder in
                    HStack {
                        Image(systemName: selectedFolders.contains(folder) ? "checkmark.square.fill" : "square")
                            .foregroundColor(.blue)
                        Text(folder)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        if enhancedFolders[folder] == true {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        selectedFolders.contains(folder) ?
                            Color.accentColor.opacity(0.2) :
                            Color.clear
                    )
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedFolders.contains(folder) {
                            selectedFolders.remove(folder)
                        } else {
                            selectedFolders.insert(folder)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            } else {
                VStack {
                    Spacer()
                    Text("No recordings found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
            }
        }
        .frame(width: 250)
        .frame(maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .leading
        )
    }
}
