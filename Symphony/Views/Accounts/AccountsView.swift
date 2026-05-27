import SwiftUI

struct AccountsView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var showAddAccount = false
    @State private var accountToRename: Account?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(authManager.accounts) { account in
                        Button {
                            authManager.selectAccount(account)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(account.keyID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if account.id == authManager.selectedAccount?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                authManager.deleteAccount(account)
                            } label: {
                                Label("Shared.Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                renameText = account.name
                                accountToRename = account
                            } label: {
                                Label("Accounts.Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                authManager.deleteAccount(account)
                            } label: {
                                Label("Shared.Delete", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("Accounts.Footer")
                }

                Section {
                    Button {
                        showAddAccount = true
                    } label: {
                        Label("Accounts.Add", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Accounts.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView()
            }
            .alert("Accounts.Rename", isPresented: Binding(
                get: { accountToRename != nil },
                set: { if !$0 { accountToRename = nil } }
            )) {
                TextField("Accounts.Name", text: $renameText)
                Button("Shared.Cancel", role: .cancel) {
                    accountToRename = nil
                }
                Button("Accounts.Save") {
                    if let account = accountToRename {
                        authManager.renameAccount(account, to: renameText)
                    }
                    accountToRename = nil
                }
            }
        }
    }
}
