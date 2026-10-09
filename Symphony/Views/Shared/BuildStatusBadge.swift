import SwiftUI

struct BuildStatusBadge: View {
    let progress: ExecutionProgress?
    let status: CompletionStatus?
    @ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 18

    var body: some View {
        Label {
            Text(labelText)
                .foregroundStyle(.secondary)
        } icon: {
            BuildStatusSymbol(progress: progress, status: status, size: iconSize)
        }
        .labelIconToTitleSpacing(4)
        .font(.subheadline)
    }

    var labelText: String {
        if let progress, progress != .complete {
            switch progress {
            case .pending: return String(localized: "Build.Status.Pending")
            case .running: return String(localized: "Build.Status.Running")
            case .complete: return String(localized: "Build.Status.Complete")
            }
        }

        guard let status else { return String(localized: "Build.Status.Unknown") }
        switch status {
        case .succeeded: return String(localized: "Build.Status.Succeeded")
        case .failed: return String(localized: "Build.Status.Failed")
        case .errored: return String(localized: "Build.Status.Errored")
        case .canceled: return String(localized: "Build.Status.Canceled")
        case .skipped: return String(localized: "Build.Status.Skipped")
        }
    }

    var iconName: String {
        if let progress, progress != .complete {
            switch progress {
            case .pending: return "clock"
            case .running: return "arrow.triangle.2.circlepath"
            case .complete: return "checkmark"
            }
        }

        guard let status else { return "questionmark" }
        switch status {
        case .succeeded: return "checkmark"
        case .failed: return "xmark"
        case .errored: return "exclamationmark"
        case .canceled: return "minus"
        case .skipped: return "forward.fill"
        }
    }

    var iconColor: Color {
        if let progress, progress != .complete {
            switch progress {
            case .pending: return .orange
            case .running: return .blue
            case .complete: return .green
            }
        }

        guard let status else { return .gray }
        switch status {
        case .succeeded: return .green
        case .failed: return .red
        case .errored: return .red
        case .canceled: return .gray
        case .skipped: return .gray
        }
    }
}

struct BuildStatusIcon: View {
    let progress: ExecutionProgress?
    let status: CompletionStatus?
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 30

    var body: some View {
        BuildStatusSymbol(progress: progress, status: status, size: iconSize)
    }
}

/// A filled circle in the status color with the status glyph drawn in white.
struct BuildStatusSymbol: View {
    let progress: ExecutionProgress?
    let status: CompletionStatus?
    let size: CGFloat

    var body: some View {
        let badge = BuildStatusBadge(progress: progress, status: status)
        Circle()
            .fill(badge.iconColor)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: badge.iconName)
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
