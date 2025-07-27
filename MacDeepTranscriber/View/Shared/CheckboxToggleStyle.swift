//
//  CheckboxToggleStyle.swift
//  MacDeepTranscriber
//
//  Created on 26.06.2025.
//

import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .accentColor : .secondary)
                .font(.system(size: 14))
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            
            configuration.label
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}
