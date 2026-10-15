import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AppLock.self) private var lock
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dashboardAppearance") private var appearance = "system"
    @AppStorage("dashboardAmbientMotion") private var ambientMotion = true
    @State private var error: String?
    @State private var locking = false
    @State private var signOut = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if case .signedIn(_, let email) = auth.state, let email { Text(email) }
                    Button("Sign out", role: .destructive) { signOut = true }
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
                    NavigationLink("Connections") { ConnectionsSettingsView() }
                    NavigationLink("Voice and appearance") { DashboardSettings(appearance: $appearance, ambientMotion: $ambientMotion) }
                    NavigationLink("Classic dashboard") { DashboardView().navigationTitle("Classic").navigationBarTitleDisplayMode(.inline) }
                }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Sign out of Mission Control?", isPresented: $signOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { Task { await auth.signOut(); dismiss() } }
            }
        }
    }
}
