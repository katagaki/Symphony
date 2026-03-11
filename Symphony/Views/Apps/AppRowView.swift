import SwiftUI

struct AppRowView: View {
    let app: CiApp
    var forceRefreshIcons: Bool = false

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
            }
        }
        .padding(.vertical, 2)
    }
}

struct AppIconView: View {
    let bundleId: String
    var forceRefresh: Bool = false
    @State private var iconURL: URL?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let iconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    case .failure:
                        placeholderIcon
                    default:
                        ProgressView()
                    }
                }
            } else if didLoad {
                placeholderIcon
            } else {
                ProgressView()
            }
        }
        .task(id: forceRefresh) {
            iconURL = await AppIconCache.shared.iconURL(for: bundleId, forceRefresh: forceRefresh)
            didLoad = true
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: 14, style: .continuous))
    }
}
