//
//  NavigationModel.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case record = "Record"
    case transcriptions = "Transcriptions"
    case learnWords = "Word Sorter"
    case aiChat = "AI Chat"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .record:
            return "mic.circle"
        case .transcriptions:
            return "doc.text"
        case .learnWords:
            return "square.3.layers.3d"
        case .aiChat:
            return "bubble.left.and.bubble.right"
        case .settings:
            return "gearshape.circle"
        }
    }
    
    func iconForState(isRecording: Bool) -> String {
        switch self {
        case .record:
            return isRecording ? "record.circle.fill" : "mic.circle"
        case .transcriptions:
            return "doc.text"
        case .learnWords:
            return "book.circle"
        case .aiChat:
            return "bubble.left.and.bubble.right"
        case .settings:
            return "gearshape.circle"
        }
    }
}

class NavigationModel: ObservableObject {
    @Published var selectedItem: SidebarItem? = .record
    @Published var columnVisibility: NavigationSplitViewVisibility = .all
}
