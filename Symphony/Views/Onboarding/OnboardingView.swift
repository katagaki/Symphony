import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var showFilePicker = false
    @State private var gearRotation: Double = 0

    var body: some View {
        @Bindable var auth = authManager

        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            Image("ConductorGear")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 128, height: 128)
                                .foregroundStyle(.tint)
                                .rotationEffect(.degrees(gearRotation))
                                .onAppear {
                                    withAnimation(
                                        .linear(duration: 30)
                                        .repeatForever(autoreverses: false)
                                    ) {
                                        gearRotation = 360
                                    }
                                }
                            Image("ConductorApp")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 128, height: 128)
                                .foregroundStyle(.tint)
                        }
                        Text("Onboarding.Description")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
                }
                .listSectionSpacing(.zero)

                Section {
                    TextField("Onboarding.IssuerID", text: $auth.issuerID)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Onboarding.KeyID", text: $auth.keyID)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Onboarding.APIKeyInfo")
                } footer: {
                    Text("Onboarding.APIKeyInfoFooter")
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
                        Label("Onboarding.ImportFromFile", systemImage: "doc.fill")
                    }
                } header: {
                    Text("Onboarding.PrivateKey")
                } footer: {
                    Text("Onboarding.PrivateKeyFooter")
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
                                Text("Onboarding.Connecting")
                            } else {
                                Text("Onboarding.Connect")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!authManager.canConnect || authManager.isValidating)
                }
            }
            .navigationTitle("Onboarding.Title")
            .toolbarTitleDisplayMode(.inline)
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
