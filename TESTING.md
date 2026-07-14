# Manual test items

Items that cannot be verified from CI/automation (CLAUDE.md: never claim
these verified from CI). Record date + hardware when performing one.

## Recovery (Milestone 2)

| Item | Procedure | Expected | Last verified |
|---|---|---|---|
| Wi-Fi → Ethernet switch mid-registration | Register, unplug/switch interface | Re-registers within ~5 s (debounced); no crash | Not verified |
| Wi-Fi off/on | Toggle Wi-Fi while registered | Status → failed/unregistered, then re-registers on reconnect | Not verified |
| VPN connect/disconnect while registered | Toggle VPN | Re-registers via new path | Not verified |
| Sleep/wake | Close lid ≥1 min with account registered | On wake: re-registers; no runtime corruption; subsequent call works | Not verified |
| Network change during active call | Switch interface mid-call | Call re-INVITEs and audio resumes, or fails cleanly to history | Not verified |

## Audio devices

| Item | Procedure | Expected | Last verified |
|---|---|---|---|
| USB headset hot-plug during call | Plug/unplug USB audio mid-call | Audio follows or stays on remaining device; no crash | Not verified |
| Bluetooth headset connect/disconnect | Pair/unpair mid-call | Same | Not verified |
| Default-device change mid-call | Change system default output | Behavior matches device-selection setting | Not verified |

## TLS

| Item | Procedure | Expected | Last verified |
|---|---|---|---|
| Trusted-CA happy path | Install TestPBX CA (`TestPBX/asterisk/keys/ca.crt`) as trusted in a THROWAWAY macOS user/VM keychain, register with TLS + verification ON | Registers without the insecure override | Not verified |

## UI (Milestone 3)

| Item | Procedure | Expected | Last verified |
|---|---|---|---|
| Main window renders to spec | Launch app | 360×560 pt; header/tabs/footer; dark + light | **2026-07-14 (dark mode, screenshot)** |
| Incoming-call panel | Call this client from the TestPBX (or another softphone) while another app has focus | Panel appears top-right, floats above other apps, does NOT steal keyboard focus, survives Space switch; Answer/Busy/Decline work; ↩/⎋ shortcuts | Not verified |
| Multiple ringing calls | Two simultaneous inbound calls | Panels stack downward, 8 pt gap; each answers independently | Not verified |
| DND | Enable DND (footer or menu bar), then call in | Caller gets busy; call appears in history as missed; no panel shown | Not verified |
| Menu bar extra | Click icon in menu bar | Icon reflects state (registered/on-call/DND); menu shows status, account switch, Dial, active-call controls, recent calls, DND, Settings, Quit | Not verified |
| Quit with active call | ⌘Q during a call | Warning sheet appears; Cancel keeps the call | Not verified |
| Launch at login | Toggle in Settings → General | Item appears in System Settings → General → Login Items (ad-hoc dev builds may need approval there) | Not verified |
| Audio device selection | Settings → Audio; pick a specific mic/speaker; make a call | Chosen device is used; selection persists across restart | Not verified |
| VoiceOver pass | VO-navigate header, tabs, keypad, in-call controls, incoming panel | All controls labeled; call/registration state announced | Not verified |
| Light mode | Switch macOS appearance to Light | Contrast holds; no hard-coded colors | Not verified |
| Multi-monitor panel placement | Ring with the app on a second display | Panel lands on the screen with keyboard focus | Not verified |
