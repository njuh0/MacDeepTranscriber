//
//  MainView.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import SwiftUI

struct MainView: View {
    @StateObject private var navigationModel = NavigationModel()
    
    var body: some View {
        NavigationSplitView(columnVisibility: $navigationModel.columnVisibility) {
            SidebarView(navigationModel: navigationModel)
        } detail: {
            DetailView(navigationModel: navigationModel)
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}

struct SidebarView: View {
    @ObservedObject var navigationModel: NavigationModel
    
    var body: some View {
        List(SidebarItem.allCases, selection: $navigationModel.selectedItem) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
            }
        }
        .navigationTitle("Audio Study")
        .listStyle(SidebarListStyle())
    }
}

struct DetailView: View {
    @ObservedObject var navigationModel: NavigationModel
    
    var body: some View {
        Group {
            if let selectedItem = navigationModel.selectedItem {
                switch selectedItem {
                case .record:
                    RecordView()
                case .learnWords:
                    LearnWordsView()
                case .aiChat:
                    AIChatView()
                case .settings:
                    SettingsView()
                }
            } else {
                WelcomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Audio Study")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Select an option from the sidebar to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    MainView()
}
