//
//  ContentView.swift
//  Symphony
//
//  Created by シン・ジャスティン on 2026/03/11.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Namespace private var namespace

    var body: some View {
        if authManager.isAuthenticated {
            NavigationStack {
                AppsListView(namespace: namespace)
                    .navigationDestination(for: CiApp.self) { app in
                        WorkflowsView(app: app)
                            .navigationTransition(.zoom(sourceID: app.id, in: namespace))
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
