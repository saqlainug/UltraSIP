import SwiftUI

/// Milestone 1 account form (single account, UDP). Existing passwords are
/// never displayed back (SPEC §1); leaving the field empty keeps the
/// stored secret.
struct AccountFormView: View {
    @ObservedObject var model: AppModel

    @State private var label = ""
    @State private var domain = ""
    @State private var username = ""
    @State private var password = ""
    @State private var authorizationID = ""
    @State private var displayName = ""
    @State private var registrar = ""

    private var isEditing: Bool { model.account != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isEditing ? "Edit SIP Account" : "Add SIP Account")
                .font(.headline)
            Form {
                TextField("Label", text: $label, prompt: Text("Work PBX"))
                TextField("SIP server", text: $domain, prompt: Text("pbx.example.com"))
                TextField("Username", text: $username, prompt: Text("101"))
                SecureField(
                    "Password", text: $password,
                    prompt: Text(isEditing ? "••••• (unchanged)" : "Required"))
                TextField("Auth ID (optional)", text: $authorizationID)
                TextField("Display name (optional)", text: $displayName)
                TextField("Registrar (optional)", text: $registrar, prompt: Text("sip:pbx.example.com"))
            }
            .formStyle(.columns)
            .textFieldStyle(.roundedBorder)

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: \(error)")
            }

            HStack {
                if isEditing {
                    Button("Cancel") { model.showAccountForm = false }
                        .keyboardShortcut(.cancelAction)
                }
                Spacer()
                Button(isEditing ? "Save" : "Save & Register") {
                    var config = model.account ?? SIPAccountConfig()
                    config.label = label
                    config.domain = domain
                    config.username = username
                    config.authorizationID = authorizationID
                    config.displayName = displayName
                    config.registrar = registrar
                    let newPassword = password
                    Task { await model.saveAccount(config, newPassword: newPassword) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(domain.isEmpty || username.isEmpty || (!isEditing && password.isEmpty))
            }
        }
        .padding(16)
        .onAppear {
            guard let account = model.account else { return }
            label = account.label
            domain = account.domain
            username = account.username
            authorizationID = account.authorizationID
            displayName = account.displayName
            registrar = account.registrar
        }
    }
}
