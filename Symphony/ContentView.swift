//
//  ContentView.swift
//  Symphony
//
//  Created by シン・ジャスティン on 2026/03/11.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var namespace
    @State private var path = ScreenshotScreen.current?.path ?? NavigationPath()
    @State private var selectedApp: CiApp? = ScreenshotScreen.current?.app
    @State private var detailPath = ScreenshotScreen.current?.detailPath ?? NavigationPath()

    var body: some View {
        if authManager.isAuthenticated {
            if horizontalSizeClass == .regular {
                splitView
            } else {
                stackView
            }
        } else {
            OnboardingView()
        }
    }

    private var stackView: some View {
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
    }

    private var splitView: some View {
        NavigationSplitView {
            AppsListView(namespace: namespace, selection: $selectedApp)
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if let selectedApp {
                        WorkflowsView(app: selectedApp)
                            .id(selectedApp.id)
                    } else {
                        ContentUnavailableView(
                            "Apps.NoSelection",
                            systemImage: "app.dashed",
                            description: Text("Apps.NoSelectionDescription")
                        )
                    }
                }
                .navigationDestination(for: BuildRunRoute.self) { route in
                    BuildRunDetailView(app: route.app, buildRun: route.buildRun)
                }
            }
        }
        .onChange(of: selectedApp) {
            detailPath = NavigationPath()
        }
        .onChange(of: authManager.selectedAccountID) {
            selectedApp = nil
        }
    }
}
