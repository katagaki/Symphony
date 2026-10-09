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
    @State private var path = ScreenshotScreen.current?.path ?? NavigationPath()

    var body: some View {
        if authManager.isAuthenticated {
            NavigationStack(path: $path) {
                AppsListView(namespace: namespace)
                    .navigationDestination(for: CiApp.self) { app in
                        WorkflowsView(app: app)
                            .navigationTransition(.zoom(sourceID: app.id, in: namespace))
                    }
                    .navigationDestination(for: BuildRunRoute.self) { route in
                        BuildRunDetailView(app: route.app, buildRun: route.buildRun)
                    }
            }
        } else {
            OnboardingView()
        }
    }
}
