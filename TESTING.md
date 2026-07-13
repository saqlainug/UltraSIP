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

## UI (pre-gate-2 baseline)

| Item | Procedure | Expected | Last verified |
|---|---|---|---|
| VoiceOver pass over M1 views | VO-navigate account form, dialer, in-call, incoming banner | All controls labeled; states announced | Not verified |
| Multi-monitor window placement | Move window across displays | No jumping; remembered position | Not verified |
