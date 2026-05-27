import SwiftUI
import UniformTypeIdentifiers

struct AddAccountView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var issuerID = ""
    @State private var keyID = ""
    @State private var privateKeyText = ""
    @State private var showFilePicker = false
    @State private var isValidating = false
    @State private var validationError: String?

    private var canConnect: Bool {
        !issuerID.trimmingCharacters(in: .whitespaces).isEmpty
            && !keyID.trimmingCharacters(in: .whitespaces).isEmpty
            && !privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Accounts.Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Accounts.Name")
                } footer: {
                    Text("Accounts.NameFooter")
                }

                Section {
                    TextField("Onboarding.IssuerID", text: $issuerID)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Onboarding.KeyID", text: $keyID)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Onboarding.APIKeyInfo")
                } footer: {
                    Text("Onboarding.APIKeyInfoFooter")
                }

                Section {
                    TextEditor(text: $privateKeyText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Onboarding.ImportFromFile", systemImage: "doc.fill")
                    }
                } header: {
                    Text("Onboarding.PrivateKey")
                } footer: {
                    Text("Onboarding.PrivateKeyFooter")
                }

                if let validationError {
                    Section {
                        Label(validationError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Accounts.Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Shared.Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isValidating {
                        ProgressView()
                    } else {
                        Button("Accounts.AddAction") {
                            Task { await add() }
                        }
                        .disabled(!canConnect)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "p8") ?? .plainText,
                    .plainText
                ],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let contents = try? String(contentsOf: url, encoding: .utf8) {
                            privateKeyText = contents
                        }
                    }
                }
            }
        }
    }

    private func add() async {
        isValidating = true
        validationError = nil
        let didAdd = await authManager.addAccount(
            name: name,
            issuerID: issuerID,
            keyID: keyID,
            privateKey: privateKeyText
        )
        isValidating = false
        if didAdd {
            dismiss()
        } else {
            validationError = authManager.validationError
        }
    }
}
