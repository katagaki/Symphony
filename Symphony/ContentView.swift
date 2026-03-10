//
//  ContentView.swift
//  Symphony
//
//  Created by シン・ジャスティン on 2026/03/11.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        if authManager.isAuthenticated {
            NavigationStack {
                AppsListView()
                    .navigationDestination(for: CiApp.self) { app in
                        WorkflowsView(app: app)
                    }
                    .navigationDestination(for: CiBuildRun.self) { buildRun in
                        BuildRunDetailView(buildRun: buildRun)
                    }
            }
        } else {
            OnboardingView()
        }
    }
}
