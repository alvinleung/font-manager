//
//  FontSizePreviewCommands.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-26.
//

import Foundation
import SwiftUI


final class FontPreviewState: ObservableObject {
    @Published var size: CGFloat = 32
}

struct FontPreviewCommands: Commands {
    @ObservedObject var state: FontPreviewState

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Button("Increase Font Size") {
                state.size = min(state.size + 1, 72)
            }
            .keyboardShortcut("+", modifiers: [.command, .shift])

            Button("Decrease Font Size") {
                state.size = max(state.size - 1, 8)
            }
            .keyboardShortcut("-", modifiers: [.command, .shift])
        }
    }
}
