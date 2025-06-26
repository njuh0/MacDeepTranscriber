
//
//  AIChatRightSidebarView.swift
//  Audio Study
//
//  Created on 26.06.2025.
//

import SwiftUI

struct AIChatRightSidebarView: View {
    let recordingsFolders: [String]
    @Binding var selectedFolder: String?
    let loadTranscriptions: (String) -> Void

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
                        Image(systemName: "book.closed")
                            .foregroundColor(.blue)
                        Text(folder)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        selectedFolder == folder ?
                            Color.accentColor.opacity(0.2) :
                            Color.clear
                    )
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFolder = folder
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            loadTranscriptions(folder)
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
