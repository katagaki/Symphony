import Foundation

nonisolated struct BuildRunRoute: Hashable, Sendable {
    let app: CiApp
    let buildRun: CiBuildRun
}
