import SwiftUI

/// Settings window (⌘,). M3 ships General · Accounts · Audio; the
/// remaining SPEC §22 sections arrive with their features (no empty
/// sections that imply unimplemented settings).
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            AccountsSettingsView(model: model)
                .tabItem { Label("Accounts", systemImage: "person.crop.circle") }
            AudioSettingsView(model: model)
                .tabItem { Label("Audio", systemImage: "speaker.wave.2") }
        }
        .frame(width: 500, height: 380)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Toggle(
                "Launch MacSIP at login",
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }))
            if LaunchAtLogin.requiresApproval {
                Text("Approve MacSIP in System Settings → General → Login Items to finish enabling this.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Toggle(
                "Do Not Disturb (reject incoming calls as busy)",
                isOn: Binding(
                    get: { model.doNotDisturb },
                    set: { model.setDoNotDisturb($0) }))

            Divider()

            LabeledContent("Appearance") {
                Text("Follows the system light/dark setting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Window") {
                Text("Closing the window keeps MacSIP running in the menu bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AccountsSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        AccountsListView(model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Real device selection: devices are enumerated from the running media
/// stack, and the choice is applied live and persisted (SPEC §9 subset).
struct AudioSettingsView: View {
    @ObservedObject var model: AppModel

    private var inputs: [AudioDevice] { model.audioDevices.filter(\.isInput) }
    private var outputs: [AudioDevice] { model.audioDevices.filter(\.isOutput) }

    var body: some View {
        Form {
            if model.audioDevices.isEmpty {
                Text("No audio devices reported. Start the SIP engine, then refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Microphone", selection: captureBinding) {
                    Text("System default").tag(AudioDevice.systemDefaultIndex)
                    ForEach(inputs) { device in
                        Text(device.name).tag(device.index)
                    }
                }
                .accessibilityLabel("Microphone device")

                Picker("Speaker", selection: playbackBinding) {
                    Text("System default").tag(AudioDevice.systemDefaultIndex)
                    ForEach(outputs) { device in
                        Text(device.name).tag(device.index)
                    }
                }
                .accessibilityLabel("Speaker device")
            }

            Button("Refresh devices") {
                Task { await model.refreshAudioDevices() }
            }

            if let error = model.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await model.refreshAudioDevices() }
    }

    private var captureBinding: Binding<Int> {
        Binding(
            get: { model.captureDeviceIndex },
            set: { index in
                Task { await model.selectAudioDevices(capture: index, playback: model.playbackDeviceIndex) }
            })
    }

    private var playbackBinding: Binding<Int> {
        Binding(
            get: { model.playbackDeviceIndex },
            set: { index in
                Task { await model.selectAudioDevices(capture: model.captureDeviceIndex, playback: index) }
            })
    }
}
