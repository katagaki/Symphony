import SwiftUI

struct TeamIDView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    var onSave: ((String) -> Void)?

    @State private var teamIDText = ""
    @State private var didParseFromURL = false

    private static let uuidRegex = /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
    private static let teamsPathRegex = /teams\/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/

    private var parsedTeamID: String? {
        let trimmed = teamIDText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Prefer the UUID following "teams/" — a full build URL also contains the build's UUID.
        if let match = trimmed.firstMatch(of: Self.teamsPathRegex) {
            return String(match.output.1).lowercased()
        }
        guard let match = trimmed.firstMatch(of: Self.uuidRegex) else { return nil }
        return String(match.output).lowercased()
    }

    private var canSave: Bool {
        parsedTeamID != nil || teamIDText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("TeamID.Placeholder", text: $teamIDText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: teamIDText) {
                            extractTeamIDFromURL()
                        }
                    if didParseFromURL {
                        Label("TeamID.Parsed", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                } footer: {
                    Text("TeamID.Footer")
                }
            }
            .navigationTitle("TeamID.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("TeamID.Save") {
                        let teamID = parsedTeamID
                        authManager.setTeamID(teamID)
                        dismiss()
                        if let teamID {
                            onSave?(teamID)
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                teamIDText = authManager.selectedTeamID ?? ""
            }
        }
    }

    /// Replaces a pasted App Store Connect URL with the team ID it contains.
    private func extractTeamIDFromURL() {
        guard teamIDText.localizedCaseInsensitiveContains("appstoreconnect.apple.com"),
              let teamID = parsedTeamID else { return }
        teamIDText = teamID
        didParseFromURL = true
    }
}
