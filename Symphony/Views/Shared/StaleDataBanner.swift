import SwiftUI

/// Shown above cached content when a refresh has failed, so the user knows the
/// data on screen may be out of date. Tapping it retries the refresh.
struct StaleDataBanner: View {
    let lastUpdated: Date?
    let retry: () async -> Void
    @State private var isRetrying = false

    var body: some View {
        Button {
            guard !isRetrying else { return }
            Task {
                isRetrying = true
                await retry()
                isRetrying = false
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Shared.StaleData.Title")
                        .font(.subheadline)
                        .bold()
                    if let lastUpdated {
                        Text("Shared.StaleData.Updated \(Text(lastUpdated, style: .relative))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if isRetrying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .accessibilityLabel(Text("Shared.StaleData.Title"))
        .accessibilityHint(Text("Shared.StaleData.RetryHint"))
    }
}
