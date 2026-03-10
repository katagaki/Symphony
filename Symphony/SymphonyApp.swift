//
//  SymphonyApp.swift
//  Symphony
//
//  Created by シン・ジャスティン on 2026/03/11.
//

import SwiftUI

@main
struct SymphonyApp: App {
    @State private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
        }
    }
}
