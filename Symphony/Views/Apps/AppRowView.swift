import SwiftUI

struct AppRowView: View {
    let app: CiApp
    var latestBuild: CiBuildRun?
    var forceRefreshIcons: Bool = false
    @ScaledMetric(relativeTo: .caption) private var statusIconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(bundleId: app.attributes.bundleId, forceRefresh: forceRefreshIcons)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.attributes.name)
                    .font(.headline)
                Text(app.attributes.bundleId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let latestBuild {
                    latestBuildStatus(latestBuild)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func latestBuildStatus(_ build: CiBuildRun) -> some View {
        let progress = build.attributes.executionProgress
        let status = build.attributes.completionStatus
        let badge = BuildStatusBadge(progress: progress, status: status)
        return HStack(spacing: 4) {
            BuildStatusSymbol(progress: progress, status: status, size: statusIconSize)
            Text(badge.labelText)
            if let number = build.attributes.number {
                Text(verbatim: "· #\(number)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

/// The latest build's status drawn as a badge for the bottom-right corner of an app icon.
struct AppIconBuildBadge: View {
    let build: CiBuildRun

    var body: some View {
        BuildStatusSymbol(
            progress: build.attributes.executionProgress,
            status: build.attributes.completionStatus,
            size: 22
        )
        .padding(2)
        .background(Circle().fill(.background))
        .offset(x: 6, y: 6)
        .accessibilityLabel(BuildStatusBadge(
            progress: build.attributes.executionProgress,
            status: build.attributes.completionStatus
        ).labelText)
    }
}

struct AppIconView: View {
    let bundleId: String
    var forceRefresh: Bool = false
    @State private var iconURL: URL?
    @State private var didLoad = false

    private var demoIconName: String? {
        DemoData.iconNames[bundleId]
    }

    var body: some View {
        GeometryReader { geometry in
            let cornerRadius = geometry.size.width * (13.0 / 60.0)
            Group {
                if let demoIconName {
                    Image(demoIconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: cornerRadius))
                } else if let iconURL {
                    AsyncImage(url: iconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(.rect(cornerRadius: cornerRadius))
                        case .failure:
                            placeholderIcon(cornerRadius: cornerRadius)
                        default:
                            ZStack(alignment: .center) {
                                placeholderIcon(cornerRadius: cornerRadius)
                                ProgressView()
                            }
                        }
                    }
                } else if didLoad {
                    placeholderIcon(cornerRadius: cornerRadius)
                } else {
                    ZStack(alignment: .center) {
                        placeholderIcon(cornerRadius: cornerRadius)
                        ProgressView()
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: forceRefresh) {
            if demoIconName != nil { return }
            iconURL = await AppIconCache.shared.iconURL(for: bundleId, forceRefresh: forceRefresh)
            didLoad = true
        }
    }

    private func placeholderIcon(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius, style: .continuous))
    }
}
