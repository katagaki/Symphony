import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var showFilePicker = false

    var body: some View {
        @Bindable var auth = authManager

        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                        Text("Welcome to Symphony")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Connect your App Store Connect account to manage Xcode Cloud builds.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Issuer ID", text: $auth.issuerID)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Key ID", text: $auth.keyID)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("API Key Information")
                } footer: {
                    Text("Find these values in App Store Connect under Users and Access > Integrations > App Store Connect API.")
                }

                Section {
                    TextEditor(text: $auth.privateKeyText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Import from File", systemImage: "doc.fill")
                    }
                } header: {
                    Text("Private Key (.p8)")
                } footer: {
                    Text("Paste the contents of your .p8 file or import it directly.")
                }

                if let error = authManager.validationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await authManager.saveCredentials()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if authManager.isValidating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Connecting...")
                            } else {
                                Text("Connect")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!authManager.canConnect || authManager.isValidating)
                }
            }
            .navigationTitle("Setup")
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
                            authManager.privateKeyText = contents
                        }
                    }
                }
            }
        }
    }
}
