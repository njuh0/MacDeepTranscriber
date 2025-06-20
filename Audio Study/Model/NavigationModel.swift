//
//  NavigationModel.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case record = "Record"
    case learnWords = "Learn words"
    case aiChat = "AI Chat"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .record:
            return "mic.circle"
        case .learnWords:
            return "book.circle"
        case .aiChat:
            return "bubble.left.and.bubble.right.circle"
        case .settings:
            return "gearshape.circle"
        }
    }
}

class NavigationModel: ObservableObject {
    @Published var selectedItem: SidebarItem? = nil
    @Published var columnVisibility: NavigationSplitViewVisibility = .all
}
