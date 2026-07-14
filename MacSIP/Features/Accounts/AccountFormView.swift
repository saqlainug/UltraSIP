import SwiftUI

/// Account form (add or edit a specific account). Stored secrets are never
/// displayed back (SPEC §1); empty password fields keep existing secrets.
struct AccountFormView: View {
    @ObservedObject var model: AppModel
    /// nil = create a new account.
    let editingAccount: SIPAccountConfig?
    var onCancel: (() -> Void)?

    @State private var label = ""
    @State private var domain = ""
    @State private var username = ""
    @State private var password = ""
    @State private var authorizationID = ""
    @State private var displayName = ""
    @State private var registrar = ""
    @State private var transport: SIPAccountConfig.Transport = .udp
    @State private var mediaEncryption: SIPAccountConfig.MediaEncryption = .none
    @State private var tlsVerificationDisabled = false
    @State private var stunServer = ""
    @State private var iceEnabled = false
    @State private var turnServer = ""
    @State private var turnUsername = ""
    @State private var turnPassword = ""

    private var isEditing: Bool { editingAccount != nil }

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
                Picker("Transport", selection: $transport) {
                    Text("UDP").tag(SIPAccountConfig.Transport.udp)
                    Text("TCP").tag(SIPAccountConfig.Transport.tcp)
                    Text("TLS").tag(SIPAccountConfig.Transport.tls)
                }
                Picker("Media encryption", selection: $mediaEncryption) {
                    Text("None").tag(SIPAccountConfig.MediaEncryption.none)
                    Text("SRTP (optional)").tag(SIPAccountConfig.MediaEncryption.srtpOptional)
                    Text("SRTP (mandatory)").tag(SIPAccountConfig.MediaEncryption.srtpMandatory)
                }
            }
            .formStyle(.columns)
            .textFieldStyle(.roundedBorder)

            if mediaEncryption != .none, transport != .tls {
                Label(
                    "SRTP keys travel in cleartext SDP without TLS signaling — use TLS transport for confidential media",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption2)
                .foregroundStyle(.orange)
                .accessibilityLabel(
                    "Warning: SRTP keys travel in cleartext without TLS signaling. Use TLS transport for confidential media"
                )
            }

            if transport == .tls {
                Toggle(isOn: $tlsVerificationDisabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Allow invalid TLS certificates")
                        Text("Insecure — disables server verification for this account only")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .accessibilityLabel(
                    "Allow invalid TLS certificates. Insecure: disables server certificate verification for this account"
                )
            }

            DisclosureGroup("NAT traversal") {
                Form {
                    TextField("STUN server", text: $stunServer, prompt: Text("stun.example.com:3478"))
                    Toggle("Enable ICE", isOn: $iceEnabled)
                    TextField("TURN server", text: $turnServer, prompt: Text("turn.example.com:3478"))
                    TextField("TURN username", text: $turnUsername)
                    SecureField(
                        "TURN password", text: $turnPassword,
                        prompt: Text(
                            isEditing && editingAccount?.turnPasswordRef.isEmpty == false
                                ? "••••• (unchanged)" : ""))
                }
                .formStyle(.columns)
                .textFieldStyle(.roundedBorder)
            }
            .font(.callout)

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: \(error)")
            }

            HStack {
                if let onCancel {
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                }
                Spacer()
                Button(isEditing ? "Save" : "Save & Register") {
                    var config = editingAccount ?? SIPAccountConfig()
                    config.label = label
                    config.domain = domain
                    config.username = username
                    config.authorizationID = authorizationID
                    config.displayName = displayName
                    config.registrar = registrar
                    config.transport = transport
                    config.mediaEncryption = mediaEncryption
                    config.tlsVerificationDisabled = transport == .tls && tlsVerificationDisabled
                    config.stunServer = stunServer
                    config.iceEnabled = iceEnabled
                    config.turnServer = turnServer
                    config.turnUsername = turnUsername
                    let newPassword = password
                    let newTURNPassword = turnPassword
                    Task {
                        await model.saveAccount(
                            config, newPassword: newPassword, newTURNPassword: newTURNPassword)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(domain.isEmpty || username.isEmpty || (!isEditing && password.isEmpty))
            }
        }
        .padding(16)
        .onAppear {
            guard let account = editingAccount else { return }
            label = account.label
            domain = account.domain
            username = account.username
            authorizationID = account.authorizationID
            displayName = account.displayName
            registrar = account.registrar
            transport = account.transport
            mediaEncryption = account.mediaEncryption
            tlsVerificationDisabled = account.tlsVerificationDisabled
            stunServer = account.stunServer
            iceEnabled = account.iceEnabled
            turnServer = account.turnServer
            turnUsername = account.turnUsername
        }
    }
}
