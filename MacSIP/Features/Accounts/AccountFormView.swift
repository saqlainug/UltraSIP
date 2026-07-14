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
    @State private var registrationEnabled = true
    @State private var registrationInterval = ""
    @State private var outboundProxy = ""
    @State private var keepaliveInterval = ""
    @State private var sessionTimerMode: SIPAccountConfig.SessionTimerMode = .optional
    @State private var sessionTimerExpiry = ""
    @State private var contactRewrite = true
    @State private var viaRewrite = true
    @State private var voicemailNumber = ""
    @State private var dialPrefix = ""

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
                    prompt: Text(
                        isEditing
                            ? "••••• (unchanged)"
                            : (registrationEnabled ? "Required" : "Optional for direct dialing")))
                TextField("Auth ID (optional)", text: $authorizationID)
                TextField("Display name (optional)", text: $displayName)
                TextField("Registrar (optional)", text: $registrar, prompt: Text("sip:pbx.example.com"))
                Picker("Transport", selection: $transport) {
                    ForEach(SIPAccountConfig.Transport.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                Picker("Media encryption", selection: $mediaEncryption) {
                    Text("None").tag(SIPAccountConfig.MediaEncryption.none)
                    Text("SRTP (optional)").tag(SIPAccountConfig.MediaEncryption.srtpOptional)
                    Text("SRTP (mandatory)").tag(SIPAccountConfig.MediaEncryption.srtpMandatory)
                }
            }
            .formStyle(.columns)
            .textFieldStyle(.roundedBorder)

            // First-class, not buried: MicroSIP "Local Account" parity —
            // direct dialing against a switch with no REGISTER.
            Toggle(isOn: $registrationEnabled) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Register with server")
                    if !registrationEnabled {
                        Text(
                            "Direct dialing: calls go straight to the SIP server; credentials are only used if it asks for them"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityLabel("Register with server")
            .accessibilityHint("Off means direct dialing without registration")

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

            DisclosureGroup("Network & registration") {
                Form {
                    TextField(
                        "Registration interval (s)", text: $registrationInterval, prompt: Text("300"))
                    TextField("Outbound proxy", text: $outboundProxy, prompt: Text("edge.example.com"))
                    TextField("Keepalive (s)", text: $keepaliveInterval, prompt: Text("15"))
                    Picker("Session timers", selection: $sessionTimerMode) {
                        Text("Off").tag(SIPAccountConfig.SessionTimerMode.off)
                        Text("Optional").tag(SIPAccountConfig.SessionTimerMode.optional)
                        Text("Required").tag(SIPAccountConfig.SessionTimerMode.required)
                    }
                    TextField("Session expiry (s)", text: $sessionTimerExpiry, prompt: Text("1800"))
                    Toggle("Contact rewrite (NAT)", isOn: $contactRewrite)
                    Toggle("Via rewrite (NAT)", isOn: $viaRewrite)
                }
                .formStyle(.columns)
                .textFieldStyle(.roundedBorder)
            }
            .font(.callout)

            DisclosureGroup("Dialing") {
                Form {
                    TextField("Voicemail number", text: $voicemailNumber, prompt: Text("*97"))
                    TextField("Dialing prefix", text: $dialPrefix, prompt: Text("9"))
                }
                .formStyle(.columns)
                .textFieldStyle(.roundedBorder)
            }
            .font(.callout)

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
                    config.registrationEnabled = registrationEnabled
                    config.registrationInterval = Self.parseSeconds(registrationInterval)
                    config.outboundProxy = outboundProxy
                    config.keepaliveInterval = Self.parseSeconds(keepaliveInterval)
                    config.sessionTimerMode = sessionTimerMode
                    config.sessionTimerExpiry = Self.parseSeconds(sessionTimerExpiry)
                    config.contactRewrite = contactRewrite
                    config.viaRewrite = viaRewrite
                    config.voicemailNumber = voicemailNumber
                    config.dialPrefix = dialPrefix
                    let newPassword = password
                    let newTURNPassword = turnPassword
                    Task {
                        await model.saveAccount(
                            config, newPassword: newPassword, newTURNPassword: newTURNPassword)
                    }
                }
                .keyboardShortcut(.defaultAction)
                // Direct-dialing accounts may have no password at all —
                // the switch may never challenge (MicroSIP parity).
                .disabled(
                    domain.isEmpty || username.isEmpty
                        || (!isEditing && password.isEmpty && registrationEnabled))
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
            registrationEnabled = account.registrationEnabled
            registrationInterval = account.registrationInterval > 0 ? String(account.registrationInterval) : ""
            outboundProxy = account.outboundProxy
            keepaliveInterval = account.keepaliveInterval > 0 ? String(account.keepaliveInterval) : ""
            sessionTimerMode = account.sessionTimerMode
            sessionTimerExpiry = account.sessionTimerExpiry > 0 ? String(account.sessionTimerExpiry) : ""
            contactRewrite = account.contactRewrite
            viaRewrite = account.viaRewrite
            voicemailNumber = account.voicemailNumber
            dialPrefix = account.dialPrefix
        }
    }

    /// Empty → 0 (stack default); non-numeric → -1 so validation rejects
    /// it with a message instead of silently zeroing.
    private static func parseSeconds(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        return Int(trimmed) ?? -1
    }
}
