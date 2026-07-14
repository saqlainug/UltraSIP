# UltraSIP UI layout spec — approval gate 2

**STATUS: DRAFT — awaiting user sign-off (CLAUDE.md gate 2). No Milestone 3
UI build-out until approved.** Baseline: MicroSIP 3.22.12 interaction model
(RESEARCH_BASELINE §1) rendered as a native macOS utility app (SPEC
"Minimalist macOS UI"). One page, everything measurable.

## Main window (AppKit `NSWindow`, SwiftUI content views)

- **Size:** 360 × 560 pt initial; resizable 340×520 → 380×620 only
  (compact utility; no full-screen). Position/size remembered.
  Standard traffic lights; close hides to menu bar when "Hide to menu
  bar" is on, else quits per policy (warn if calls active).
- **Vertical structure** (top → bottom):

| Region | Height | Contents |
|---|---|---|
| Header | 44 pt | Registration dot (9 pt, green/yellow/red/gray) · account switcher menu (label + status caption) · right-aligned: re-register ↻, DND toggle, gear menu |
| Tab bar | 28 pt | `NSSegmentedControl`: **Dialpad · Calls · Contacts** (⌘1/⌘2/⌘3) |
| Content | flexible | active tab |
| Status footer | 22 pt | left: transport/encryption badges (TLS 🔒, SRTP) · right: toggles row AA / FWD / AC indicators (click = toggle, M4 wires behavior) |

- **Live-call overlay:** active/incoming call cards insert between header
  and tab bar (as today), pushing content; max 3 stacked, then scroll.

## Dialpad tab

- Destination field (full width, 28 pt) with inline ⌫; suggestions
  dropdown (recent + contacts, M5) below.
- 3×4 keypad grid: keys 72×44 pt, 6 pt gutters; digits + letters
  sublabels; long-press 0 → "+". Keyboard digits/⌫ always work; keys play
  DTMF when a call is active, else type into the field.
- Bottom row (36 pt): **Call** (green, ⌘↩ / ↩ when field focused) ·
  Video call (disabled until M6) · Redial (↺, last number) · Voicemail
  (envelope, visible when the account has a voicemail number).

## Calls tab

- Table rows 36 pt: direction glyph (color-coded missed=red) · name/URI ·
  time · right-aligned talk duration **or** orange outcome text ·
  recording/🔒 indicators (when applicable).
- Double-click / ↩ = redial. Context menu: Call, Copy, Add to Contacts
  (M5), Delete, Clear history…. Search field appears with ⌘F (filter as
  you type). Date section headers (Today/Yesterday/date).

## Contacts tab (functional at M5; tab present from M3 with empty state)

- Search field pinned top; rows 36 pt: presence dot (M5) · name ·
  primary URI; favorites section first. ↩ = call; context menu: Call,
  Message (M6), Edit, Delete.

## Incoming-call panel (separate `NSPanel`)

- 340 × 128 pt, **top-right of the active screen**, 16 pt margins;
  floating level, joins all Spaces, never steals key focus from other
  apps; multi-monitor: screen with keyboard focus. Never repositions
  itself once shown.
- Contents: caller display name (headline) · URI (caption) · receiving
  account + audio/video glyph · buttons **Answer** (green, ↩), **Busy**,
  **Decline** (red, ⎋). Multiple calls stack downward (8 pt gap).
- If panel suppressed (setting) → UserNotification with Answer/Decline
  actions instead.

## Menu bar extra (`NSStatusItem`)

- Icon reflects state: idle/registered ✆, registering (pulsing), failed
  (badge), on-call (filled). Menu: registration status line (disabled) ·
  account submenu (switch) · **Dial…** (opens window, focuses field) ·
  active-call items (mute/hold/hang up) · recent 5 calls (redial) · DND
  toggle · Show/Hide UltraSIP (⌥ click = toggle window) · Settings… ·
  Quit (warns during active calls).

## Settings (`NSWindow`, standard ⌘,)

- Native toolbar-style settings window (560 × 420 pt), sections per SPEC
  §22 added as their milestones land: General · Accounts · Audio ·
  Calls · Network · Security · Advanced (M3 ships General/Accounts/Audio;
  the current in-window account sheet migrates here).

## Keyboard map (global within app)

⌘1/2/3 tabs · ⌘L focus dial field · ↩ call/answer · ⎋ hang up/decline ·
⌘M mute · ⌘⇧H hold · 0-9,*,# DTMF during call · ⌘, settings · ⌘W hide.
F2 answer / F4 hang up (MicroSIP parity, remappable later).

## Appearance & accessibility

System light/dark via semantic colors only; SF Symbols; no decorative
animation (respect Reduce Motion); every control labeled for VoiceOver
with state announcements (registration, call state, mute) via
accessibility notifications; full keyboard navigation, visible focus
rings; minimum hit target 24×24 pt; contrast ≥ 4.5:1 for status colors in
both appearances.

## Explicit non-goals for M3

Call Manager window (M4) · messaging UI (M6) · video surfaces (M6) ·
presence/BLF indicators (M5) · shortcuts row (M5).
