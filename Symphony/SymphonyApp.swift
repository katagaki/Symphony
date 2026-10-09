//
//  SymphonyApp.swift
//  Symphony
//
//  Created by シン・ジャスティン on 2026/03/11.
//

import AppIntents
import SwiftUI

@main
struct SymphonyApp: App {
    @State private var authManager: AuthenticationManager

    init() {
        let authManager = AuthenticationManager()
        _authManager = State(initialValue: authManager)
        // Share the live accounts with App Intents so shortcuts act on the selected account.
        AppDependencyManager.shared.add(dependency: authManager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
        }
    }
}
