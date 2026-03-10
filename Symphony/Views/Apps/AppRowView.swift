import SwiftUI

struct AppRowView: View {
    let app: CiApp

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(bundleId: app.attributes.bundleId)
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
        .task {
            iconURL = await Self.fetchIconURL(bundleId: bundleId)
            didLoad = true
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "app.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.secondary)
            .padding(12)
    }

    private static func fetchIconURL(bundleId: String) async -> URL? {
        guard let lookupURL = URL(
            string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)"
        ) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: lookupURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let results = json?["results"] as? [[String: Any]]
            if let artworkString = results?.first?["artworkUrl512"] as? String,
               let url = URL(string: artworkString) {
                return url
            }
        } catch {
            // Fall through to return nil
        }
        return nil
    }
}
