import SwiftUI

struct AppRowView: View {
    let app: CiApp

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(app.attributes.name)
                .font(.headline)
            Text(app.attributes.bundleId)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
