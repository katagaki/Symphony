import SwiftUI

/// A screen staged for the App Store screenshots, from the `-ScreenshotScreen` launch argument
/// that `Assets/App Store/capture.sh` passes. Either one starts the app in demo mode.
enum ScreenshotScreen: String {
    case apps
    case builds

    static var current: ScreenshotScreen? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "ScreenshotScreen").flatMap(ScreenshotScreen.init)
        #else
        nil
        #endif
    }

    /// The app selected in the split view. Both screens show its builds beside the list, so
    /// the detail column is never left empty.
    var app: CiApp? {
        DemoData.apps.first(where: { $0.id == "demo-app-sirius" })
    }

    /// The navigation path the stack opens on.
    var path: NavigationPath {
        var path = NavigationPath()
        if self == .builds, let app {
            path.append(app)
        }
        return path
    }

    /// The navigation path the split view's detail column opens on. The builds already show
    /// beside the list, so this goes one further, into a build.
    var detailPath: NavigationPath {
        var path = NavigationPath()
        if self == .builds, let app,
           let buildRun = DemoData.buildRuns(forWorkflowID: "\(app.id)-workflow-ios")
               .first(where: { $0.attributes.completionStatus == .succeeded }) {
            path.append(BuildRunRoute(app: app, buildRun: buildRun))
        }
        return path
    }
}
