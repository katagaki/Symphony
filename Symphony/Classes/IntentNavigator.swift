import Foundation
import Observation

/// Hands navigation requests from App Intents to the view hierarchy.
@Observable
final class IntentNavigator {
    static let shared = IntentNavigator()

    /// An app to show, set by an intent and cleared once the UI has navigated to it.
    var pendingApp: CiApp?

    private init() {}
}
