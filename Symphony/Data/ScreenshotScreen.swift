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

    /// The navigation path the screen opens on.
    var path: NavigationPath {
        var path = NavigationPath()
        if self == .builds, let app = DemoData.apps.first(where: { $0.id == "demo-app-sirius" }) {
            path.append(app)
        }
        return path
    }
}
