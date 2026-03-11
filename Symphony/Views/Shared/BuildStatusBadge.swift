import SwiftUI

struct BuildStatusBadge: View {
    let progress: ExecutionProgress?
    let status: CompletionStatus?

    var body: some View {
        Label {
            Text(labelText)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .symbolRenderingMode(.hierarchical)
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
            case .pending: return "clock.fill"
            case .running: return "arrow.triangle.2.circlepath"
            case .complete: return "checkmark.circle.fill"
            }
        }

        guard let status else { return "questionmark.circle.fill" }
        switch status {
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .errored: return "exclamationmark.triangle.fill"
        case .canceled: return "minus.circle.fill"
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

        guard let status else { return .secondary }
        switch status {
        case .succeeded: return .green
        case .failed: return .red
        case .errored: return .red
        case .canceled: return .secondary
        case .skipped: return .secondary
        }
    }
}

struct BuildStatusIcon: View {
    let progress: ExecutionProgress?
    let status: CompletionStatus?

    var body: some View {
        let badge = BuildStatusBadge(progress: progress, status: status)
        Image(systemName: badge.iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(badge.iconColor)
            .font(.title)
    }
}
