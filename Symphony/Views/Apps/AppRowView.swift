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
        GeometryReader { geometry in
            let cornerRadius = geometry.size.width * (13.0 / 60.0)
            Group {
                if let iconURL {
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
