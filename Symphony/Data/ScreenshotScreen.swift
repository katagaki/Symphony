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

    /// The app the screen opens on, if any.
    var app: CiApp? {
        guard self == .builds else { return nil }
        return DemoData.apps.first(where: { $0.id == "demo-app-sirius" })
    }

    /// The navigation path the screen opens on.
    var path: NavigationPath {
        var path = NavigationPath()
        if let app {
            path.append(app)
        }
        return path
    }
}
