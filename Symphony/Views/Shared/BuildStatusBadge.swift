import SwiftUI

struct BuildStatusBadge: View {
    let progress: ExecutionProgress?
    let status: CompletionStatus?

    var body: some View {
        Label {
            Text(labelText)
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
        }
        .font(.caption)
    }

    private var labelText: String {
        if let progress, progress != .complete {
            switch progress {
            case .pending: return "Pending"
            case .running: return "Running"
            case .complete: return "Complete"
            }
        }

        guard let status else { return "Unknown" }
        switch status {
        case .succeeded: return "Succeeded"
        case .failed: return "Failed"
        case .errored: return "Errored"
        case .canceled: return "Canceled"
        case .skipped: return "Skipped"
        }
    }

    private var iconName: String {
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

    private var iconColor: Color {
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
