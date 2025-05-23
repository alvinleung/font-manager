//
//  FontManagerApp.swift
//  FontManager
//
//  Created by alvin leung on 2025-05-22.
//

import SwiftUI

@main
struct FontManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 600) // Set minimum size
                .edgesIgnoringSafeArea(.top)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        //        .windowStyle(.hiddenTitleBar)
//        .windowToolbarStyle(.unified)
    }
}

