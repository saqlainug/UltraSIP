import SwiftUI

/// Status footer (docs/UI_LAYOUT_SPEC.md): transport + media-encryption
/// badges on the left, DND on the right.
///
/// Spec deviation (deliberate): the AA / FWD / AC indicators from the
/// approved layout are NOT shown yet — auto-answer, forwarding, and
/// auto-conference land in Milestone 4, and the project forbids controls
/// that imply unimplemented functionality. They take their reserved place
/// here when their features ship.
struct StatusFooterView: View {
    @ObservedObject var model: AppModel

    private var transportBadge: String? {
        guard let account = model.account else { return nil }
        return account.transport.rawValue.uppercased()
    }

    private var isEncryptedSignaling: Bool {
        model.account?.transport == .tls
    }

    private var encryptionBadge: String? {
        switch model.account?.mediaEncryption {
        case .srtpMandatory: "SRTP"
        case .srtpOptional: "SRTP?"
        default: nil
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if let transportBadge {
                HStack(spacing: 3) {
                    if isEncryptedSignaling {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .accessibilityHidden(true)
                    }
                    Text(transportBadge)
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(isEncryptedSignaling ? Color.green : Color.secondary)
                .accessibilityLabel(
                    "Signaling transport \(transportBadge)\(isEncryptedSignaling ? ", encrypted" : "")")
            }
            if let encryptionBadge {
                Text(encryptionBadge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.green)
                    .accessibilityLabel("Media encryption \(encryptionBadge)")
            }
            Spacer()
            Toggle(isOn: dndBinding) {
                Text("DND").font(.system(size: 9, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.mini)
            .help("Do Not Disturb — reject incoming calls as busy")
            .accessibilityLabel("Do Not Disturb")
            .accessibilityValue(model.doNotDisturb ? "on" : "off")
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
    }

    private var dndBinding: Binding<Bool> {
        Binding(
            get: { model.doNotDisturb },
            set: { model.setDoNotDisturb($0) })
    }
}
