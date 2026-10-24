import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AppLock.self) private var lock
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var locking = false
    @State private var signOut = false
    @State private var deleteAccount = false
    @State private var deleting = false
    @State private var deleteError: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if case .signedIn(_, let email) = auth.state, let email { Text(email) }
                    Button("Sign out", role: .destructive) { signOut = true }
                    Button("Delete account", role: .destructive) { deleteAccount = true }.disabled(deleting)
                    if let deleteError { Text(deleteError).foregroundStyle(Tok.critical) }
                }
                Section("Privacy") {
                    Toggle("Require Face ID or passcode", isOn: Binding(get: { lock.enabled }, set: { on in
                        locking = true
                        Task { error = await lock.setEnabled(on); locking = false }
                    })).disabled(locking)
                    if let error { Text(error).foregroundStyle(Tok.critical) }
                }
                Section {
                    NavigationLink("Agents") { AgentsSettingsView() }
                    NavigationLink("Models") { ModelsSettingsView() }
                    NavigationLink("Connections") { ConnectionsSettingsView() }
                }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Sign out of Mission Control?", isPresented: $signOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { Task { await auth.signOut(); dismiss() } }
            }
            .confirmationDialog("Delete your account?", isPresented: $deleteAccount, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) {
                    deleting = true
                    Task {
                        deleteError = await auth.deleteAccount()
                        deleting = false
                        if deleteError == nil { dismiss() }
                    }
                }
            } message: {
                Text("This permanently deletes your sign-in. It can't be undone.")
            }
        }
    }
}
