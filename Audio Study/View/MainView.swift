//
//  MainView.swift
//  Audio Study
//
//  Created on 20.06.2025.
//

import SwiftUI

struct MainView: View {
    @StateObject private var navigationModel = NavigationModel()
    @StateObject private var audioCaptureService = AudioCaptureService()
    
    var body: some View {
        NavigationSplitView(columnVisibility: $navigationModel.columnVisibility) {
            SidebarView(navigationModel: navigationModel, audioCaptureService: audioCaptureService)
        } detail: {
            DetailView(navigationModel: navigationModel, audioCaptureService: audioCaptureService)
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}

struct SidebarView: View {
    @ObservedObject var navigationModel: NavigationModel
    @ObservedObject var audioCaptureService: AudioCaptureService
    
    var body: some View {
        List(SidebarItem.allCases, selection: $navigationModel.selectedItem) { item in
            NavigationLink(value: item) {
                HStack {
                    Image(systemName: item.iconForState(isRecording: audioCaptureService.isCapturing))
                        .foregroundColor(item == .record && audioCaptureService.isCapturing ? .red : .primary)
                        .scaleEffect(item == .record && audioCaptureService.isCapturing ? 1.1 : 1.0)
                        .opacity(item == .record && audioCaptureService.isCapturing ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), 
                                 value: audioCaptureService.isCapturing)
                    Text(item.rawValue)
                        .foregroundColor(item == .record && audioCaptureService.isCapturing ? .red : .primary)
                        .animation(.easeInOut(duration: 0.3), value: audioCaptureService.isCapturing)
                }
            }
        }
        .navigationTitle("Audio Study")
        .listStyle(SidebarListStyle())
    }
}

struct DetailView: View {
    @ObservedObject var navigationModel: NavigationModel
    @ObservedObject var audioCaptureService: AudioCaptureService
    
    var body: some View {
        Group {
            if let selectedItem = navigationModel.selectedItem {
                switch selectedItem {
                case .record:
                    RecordView(audioCaptureService: audioCaptureService)
                case .transcriptions:
                    TranscriptionsView(audioCaptureService: audioCaptureService)
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
