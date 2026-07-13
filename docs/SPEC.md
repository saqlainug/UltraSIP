You are the principal macOS, Swift, Objective-C++, C++, SIP, RTP, real-time media, security, testing, and release engineer responsible for building a production-grade native macOS softphone.

# Primary objective

Build a free and open-source native macOS softphone that provides functional parity with the current stable version of MicroSIP for Windows while preserving its compact, minimalist, utility-focused interaction model.

The application must be a genuine SIP softphone. Do not build:

* A UI-only prototype
* A collection of mock screens
* A simulated dialer
* A web application
* An Electron application
* A wrapper around an external softphone
* An incomplete proof of concept presented as production-ready

The application must perform real:

* SIP registration
* SIP authentication
* Incoming and outgoing calling
* RTP and RTCP media
* Audio-device management
* Video calling
* DTMF
* Call transfer
* Conferencing
* Presence and BLF
* SIP messaging
* Recording
* Call history
* Contact management
* NAT traversal
* TLS and media encryption
* Diagnostics
* Packaging for macOS

Use this provisional identity:

* Product name: `MacSIP`
* Repository name: `macsip`
* Bundle identifier: `com.example.macsip`
* Minimum supported macOS: macOS 13 Ventura
* Supported CPU architectures:

  * Apple Silicon arm64
  * Intel x86_64
* Primary language: Swift
* UI framework: SwiftUI with AppKit integration
* SIP and media stack: PJSIP/PJSUA2

Make the product name, bundle identifier, signing identity, team identifier, update URL, and application-group identifier configurable from centralized project configuration rather than scattering them throughout the source code.

# Important interpretation of “same as MicroSIP”

Implement functional parity, compactness, and equivalent workflows.

Do not copy:

* The MicroSIP name
* MicroSIP trademarks
* MicroSIP logos
* MicroSIP icons
* MicroSIP screenshots
* MicroSIP resource files
* Proprietary image assets
* Copyrightable UI text
* Windows-specific implementation code
* Windows registry behavior
* Code from MicroSIP without first resolving its license implications

Create an original native macOS implementation.

Use public documentation, SIP standards, PJSIP documentation, observable behavior, and independently written code.

# Claude Code operating instructions

## Initial repository setup

Before substantial implementation:

1. Inspect the complete repository.
2. Inspect the installed development environment.
3. Run read-only environment checks, including:

   * `git status`
   * `xcodebuild -version`
   * `swift --version`
   * `clang --version`
   * `cmake --version`
   * `ninja --version`
   * `brew --version`, if Homebrew is installed
   * available macOS SDKs
   * available simulators only if any shared iOS code is introduced
4. Run `/init` if a useful `CLAUDE.md` does not already exist.
5. Refine the generated `CLAUDE.md` rather than accepting a generic file.
6. Create a baseline Git commit before major changes if the repository is clean.
7. Enter Plan mode for architectural or cross-cutting changes.
8. Inspect relevant official documentation before choosing dependency versions or APIs.
9. Do not ask the user to manually perform repository work that can be performed safely within the repository.
10. Continue from planning into implementation unless an action requires credentials, signing secrets, paid licenses, or another unavailable external resource.

## Required Claude Code project files

Create and maintain:

```text
CLAUDE.md
CLAUDE.local.md.example
.claude/
├── settings.json
├── agents/
│   ├── sip-architect.md
│   ├── macos-engineer.md
│   ├── rtc-test-engineer.md
│   ├── security-reviewer.md
│   ├── licensing-reviewer.md
│   └── ui-accessibility-reviewer.md
└── skills/
    ├── build-and-verify/
    │   └── SKILL.md
    ├── sip-feature-slice/
    │   └── SKILL.md
    ├── interoperability-test/
    │   └── SKILL.md
    ├── release-check/
    │   └── SKILL.md
    └── dependency-review/
        └── SKILL.md
```

Do not create configuration files merely to satisfy this directory structure. Each file must contain useful, project-specific instructions.

## `CLAUDE.md` requirements

Keep `CLAUDE.md` concise enough to remain useful in every session.

It must contain:

* Project purpose
* Supported macOS versions
* Architecture summary
* Mandatory build command
* Mandatory unit-test command
* Integration-test command
* Formatting and lint command
* Dependency build command
* Packaging command
* Directory conventions
* Swift and Objective-C++ coding rules
* SIP threading rules
* Security rules
* Secrets-handling rules
* Git workflow
* Definition of done
* Files and directories that must not be edited casually
* Requirement to update documentation and parity status with implementation changes
* Requirement to report actual test output rather than assuming success

Do not place large tutorials, full feature specifications, or lengthy checklists in `CLAUDE.md`. Put repeatable procedures in skills and detailed technical material in normal project documentation.

## Project permissions

Create `.claude/settings.json` with a conservative project-level policy.

Use narrow allow rules for ordinary development commands such as:

* Reading repository files
* Editing repository files
* `git status`
* `git diff`
* `git log`
* `git show`
* `swift test`
* approved `xcodebuild` commands
* repository-local scripts
* approved formatting and linting commands
* approved CMake and Ninja build commands
* Docker Compose commands used only for the included test PBX
* read-only documentation retrieval from approved official domains

Require confirmation for:

* Package installation
* Homebrew changes
* Writing outside the repository
* Deleting substantial directories
* Force operations
* Network downloads
* Docker image downloads
* Code signing
* Notarization
* Publishing releases
* Sending data to external services
* Changing macOS security settings
* Accessing Keychain entries
* Accessing user contacts
* Opening real microphones or cameras during automated tests
* Commands requiring `sudo`

Deny or avoid:

* Reading `.env` files unless explicitly approved
* Reading signing keys
* Reading private keys
* Reading provisioning profiles unnecessarily
* Reading unrelated home-directory files
* Reading browser profiles
* Reading unrelated SSH credentials
* `git push --force`
* destructive recursive deletion outside known build directories
* `sudo` by default
* `curl | sh`
* disabling TLS verification
* `--dangerously-skip-permissions`
* commands that transmit source code or logs to unapproved services
* automatic execution of downloaded binaries

Do not weaken permissions merely to avoid approval prompts.

## Hooks

Do not add command hooks by default.

A hook may be added only when it provides deterministic, high-value enforcement that cannot be achieved adequately with CI or repository scripts.

Examples of potentially acceptable hooks:

* Preventing edits to generated PJSIP artifacts
* Running a fast formatter on edited Swift files
* Blocking accidental commits of credential files
* Warning when generated code is edited directly

Before enabling a hook:

1. Place its implementation in a version-controlled repository script.
2. Review the complete script.
3. Use absolute repository-derived paths.
4. Quote all shell variables.
5. Validate every path and input.
6. Prevent path traversal.
7. Exclude secret files.
8. Ensure the hook cannot write outside the repository.
9. Document exactly when it runs.
10. Add tests for non-trivial hook logic.
11. Do not use unreviewed inline shell snippets in settings.

Do not use hooks to run lengthy builds on every tool call.

## Subagent usage

Use specialized subagents for bounded work.

Recommended delegation:

### `sip-architect`

Use for:

* SIP state-machine design
* PJSIP/PJSUA2 API research
* Registration lifecycle
* Call lifecycle
* Transfer and conference design
* NAT traversal design
* Threading and object-lifetime review

### `macos-engineer`

Use for:

* SwiftUI/AppKit integration
* Window lifecycle
* menu bar integration
* device changes
* permissions
* sleep/wake
* Contacts integration
* signing and notarization structure

### `rtc-test-engineer`

Use for:

* Asterisk or FreeSWITCH test environment
* SIPp scenarios
* media verification
* packet-loss testing
* call-flow automation
* interoperability matrix

### `security-reviewer`

Use for:

* Threat-model review
* credential storage
* TLS policy
* import validation
* URL scheme and local IPC review
* command-hook review
* diagnostic redaction
* dependency-risk review

This agent should normally be read-only unless specifically asked to fix a confirmed issue.

### `licensing-reviewer`

Use for:

* PJSIP licensing
* MicroSIP licensing implications
* codec licenses
* patent-sensitive components
* third-party notice requirements
* binary redistribution requirements

This agent must distinguish between confirmed license text and assumptions. It must not provide unsupported legal conclusions.

### `ui-accessibility-reviewer`

Use for:

* compact UI review
* macOS conventions
* VoiceOver
* keyboard navigation
* contrast
* focus order
* reduced motion
* control sizing
* information density

Subagents must return concise findings with:

* Evidence
* Relevant files
* Risks
* Recommended action
* Verification steps

Do not delegate overlapping edits to multiple agents in the same files unless isolated Git worktrees are being used.

## Skills

Create focused Claude Code skills for recurring procedures.

### `build-and-verify`

It must define the canonical sequence for:

* Clean build
* Debug build
* Release build
* Unit tests
* Integration tests
* Static analysis
* Sanitizer runs
* Result reporting

### `sip-feature-slice`

It must require each SIP feature to be implemented vertically through:

* Domain model
* State machine
* PJSIP bridge
* Repository or persistence changes
* UI
* Logging
* Tests
* Documentation
* Parity-matrix update

### `interoperability-test`

It must explain how to:

* Start the local PBX
* Provision test extensions
* Execute SIPp scenarios
* Capture sanitized logs
* Confirm media in both directions
* Record results in the interoperability matrix

### `dependency-review`

It must require:

* Official source
* Exact version or commit
* Checksum
* License
* Transitive dependencies
* Security advisories
* Build flags
* Supported architectures
* Reproducibility
* Update procedure

### `release-check`

It must include:

* Clean clone test
* Dependency bootstrap
* Universal build
* Automated tests
* license-notice validation
* signing checks
* Hardened Runtime checks
* notarization checks
* artifact inspection
* secret scan
* release notes
* known limitations

## Session discipline

At the beginning of each substantial session:

1. Read `CLAUDE.md`.
2. Read current Git status.
3. Read the relevant milestone and parity entries.
4. Inspect related tests before modifying implementation.
5. State the concrete implementation slice being attempted.
6. Avoid loading unrelated files into context.
7. Use Explore or a research subagent for broad codebase investigation.
8. Use Plan mode before multi-module changes.
9. Keep a task list for work spanning several components.

At the end of each substantial session:

1. Run the relevant build.
2. Run relevant tests.
3. Inspect `git diff`.
4. Run `/review`.
5. Run `/security-review` for security-sensitive changes.
6. Update documentation.
7. Update `PARITY_MATRIX.md`.
8. Leave the repository buildable.
9. Report unresolved failures honestly.
10. Provide the next highest-priority vertical slice.

Use Git commits as durable checkpoints. Do not rely solely on Claude Code session history or file checkpoints.

# Research requirements

Before implementation, verify from official or primary sources:

* Current stable MicroSIP release
* Current documented MicroSIP functionality
* Current stable PJSIP release
* PJSIP macOS build support
* PJSUA2 Swift integration pattern
* TLS backend options
* Available audio and video codecs
* Codec redistribution terms
* Apple APIs required for macOS permissions
* Current launch-at-login API
* Current signing and notarization requirements
* Current Swift language and concurrency behavior supported by the installed Xcode version

Record findings in:

* `docs/RESEARCH_BASELINE.md`
* `DEPENDENCY_LICENSES.md`
* `PARITY_MATRIX.md`

For every research finding, include:

* Source
* Retrieval date
* Relevant version
* Decision affected by the finding
* Any uncertainty

Prefer:

* Official MicroSIP documentation
* Official PJSIP documentation and source
* Apple Developer documentation
* IETF RFCs
* Official dependency repositories
* Official license files

Do not rely on blog posts when a primary source exists.

# Licensing and clean-room requirements

Before selecting the final project license:

1. Inspect MicroSIP’s exact license.
2. Inspect PJSIP’s exact license.
3. Inspect every linked library and codec.
4. Determine whether the intended distribution model is compatible with those licenses.
5. Document commercial-license alternatives where applicable.
6. Do not guess that a codec is royalty-free.
7. Do not bundle a codec solely because PJSIP has an interface for it.
8. Do not copy MicroSIP source unless the consequences are explicitly understood and documented.

Create:

* `LICENSE`
* `THIRD_PARTY_NOTICES.md`
* `DEPENDENCY_LICENSES.md`
* `docs/CLEAN_ROOM_PROCESS.md`

The clean-room document must distinguish:

* Publicly documented behavior
* Observed interaction behavior
* Independently designed implementation
* Third-party source used
* Generated code
* Original project assets

# Technology requirements

## Application

Use:

* Swift using the language mode supported by the installed stable Xcode
* SwiftUI for primary UI
* AppKit where macOS-specific behavior requires it
* Swift concurrency
* `@MainActor` for UI state
* Actors or a dedicated serial execution context for SIP operations
* AVFoundation where appropriate
* UserNotifications
* Security framework and Keychain Services
* OSLog
* XCTest
* Core Data or a clearly justified SQLite repository
* Xcode build settings suitable for Debug and Release

Do not use:

* Electron
* React Native
* Flutter
* Mac Catalyst
* WebViews as the primary UI
* A hand-written SIP stack
* A hand-written RTP stack
* Plaintext password storage
* Global mutable PJSIP state accessed from arbitrary threads
* Force-unwrapped production logic without a compelling invariant
* Silent error swallowing

## SIP and media stack

Use a pinned stable PJSIP/PJSUA2 release.

Build reproducibly for:

* arm64
* x86_64
* Debug
* Release

Prefer an XCFramework or another reproducible Xcode-compatible binary layout.

Provide:

```text
scripts/bootstrap.sh
scripts/build-pjsip.sh
scripts/build-universal.sh
scripts/build-debug.sh
scripts/build-release.sh
scripts/test.sh
scripts/integration-test.sh
scripts/lint.sh
scripts/package.sh
scripts/sign.sh
scripts/notarize.sh
scripts/clean-generated.sh
```

Every script must:

* Use strict shell behavior
* Resolve the repository root safely
* Validate required tools
* Fail clearly
* Avoid writing outside documented directories
* Avoid leaking credentials
* Print actionable errors
* Be suitable for CI where practical

Pin:

* Version or Git commit
* Download URL
* SHA-256 checksum
* Build flags
* Enabled transports
* Enabled codecs
* TLS backend
* Architecture settings
* Deployment target

Do not commit opaque precompiled binaries without a reproducible source-build process.

## Swift to PJSUA2 bridge

Use PJSUA2 through a controlled Objective-C++ bridge.

Do not expose raw C++ types to Swift.

The bridge must:

* Own PJSIP objects explicitly
* Translate C++ exceptions into typed Swift-visible errors
* Translate callbacks into immutable event values
* Avoid returning pointers with ambiguous lifetime
* Avoid exposing PJSIP-owned string buffers
* Document ownership
* Document callback threading
* Guard shutdown
* Avoid use-after-free during call disconnection
* Be testable independently where possible

# Architecture

Use a layered architecture similar to:

```text
MacSIP/
├── App/
│   ├── MacSIPApp.swift
│   ├── AppDelegate.swift
│   ├── AppEnvironment.swift
│   ├── AppCommands.swift
│   └── AppLifecycleCoordinator.swift
├── Features/
│   ├── Onboarding/
│   ├── Dialer/
│   ├── ActiveCall/
│   ├── IncomingCall/
│   ├── CallManager/
│   ├── Contacts/
│   ├── History/
│   ├── Messaging/
│   ├── Accounts/
│   ├── Presence/
│   ├── Shortcuts/
│   ├── Settings/
│   └── Diagnostics/
├── Domain/
│   ├── Accounts/
│   ├── Calls/
│   ├── Contacts/
│   ├── Messaging/
│   ├── Presence/
│   ├── Media/
│   └── Diagnostics/
├── SIPCore/
│   ├── Bridge/
│   ├── Engine/
│   ├── Configuration/
│   ├── StateMachines/
│   ├── Events/
│   ├── Media/
│   └── Models/
├── Persistence/
│   ├── Models/
│   ├── Repositories/
│   ├── Migrations/
│   └── ImportExport/
├── Security/
│   ├── KeychainStore.swift
│   ├── CertificatePolicy.swift
│   ├── LogRedactor.swift
│   ├── ImportValidator.swift
│   └── SecureFileWriter.swift
├── Platform/
│   ├── AudioDevices/
│   ├── VideoDevices/
│   ├── Headsets/
│   ├── Notifications/
│   ├── MenuBar/
│   ├── Contacts/
│   ├── URLHandling/
│   ├── LocalIPC/
│   └── LaunchAtLogin/
├── Shared/
│   ├── Components/
│   ├── Utilities/
│   └── Extensions/
├── Resources/
├── Tests/
├── UITests/
├── IntegrationTests/
├── TestPBX/
├── scripts/
└── docs/
```

Use protocol boundaries between:

* UI and domain
* Domain and SIP engine
* Domain and persistence
* Domain and operating-system services

This must allow:

* Deterministic SwiftUI previews
* Unit tests without a SIP server
* Integration tests using the real SIP engine
* Mock media devices
* Mock notification behavior
* Replacement of persistence implementation
* Isolation of PJSIP-specific types

# SIP runtime and threading

PJSIP callbacks may occur outside the main thread.

Implement:

* One explicitly owned SIP runtime
* One serialized SIP execution context
* Explicit endpoint lifecycle
* Explicit transport lifecycle
* Explicit account lifecycle
* Explicit call lifecycle
* Explicit media lifecycle
* Explicit conference lifecycle
* Immutable domain events
* Main-actor UI publication
* Protection against stale callbacks
* Protection against duplicate callback delivery
* Stable account IDs
* Stable call IDs
* Safe call-object destruction
* Deterministic shutdown
* Timeout handling
* Cancellation handling
* Network-change recovery
* Sleep/wake recovery
* Audio-device-change recovery

Never mutate SwiftUI observable state directly from a PJSIP callback.

Never perform blocking SIP operations on the main thread.

Document state machines for:

* Application runtime
* Registration
* Outgoing call
* Incoming call
* Early media
* Connected call
* Hold and resume
* Multiple calls
* Blind transfer
* Attended transfer
* Conference
* Recording
* Video media
* Shutdown

Create diagrams in `docs/SIP_STATE_MACHINES.md`.

# Functional parity requirements

Validate these requirements against the current MicroSIP baseline. Add any missing current MicroSIP functionality to `PARITY_MATRIX.md`.

## 1. SIP accounts

Implement:

* Add account
* Edit account
* Delete account
* Enable or disable account
* Multiple stored accounts
* Select active account
* Switch account without restart
* Local account for direct SIP/IP calls without registration
* Registration status
* Registration progress
* Registration refresh
* Manual re-registration
* Registration failure details
* Recovery after network changes
* Recovery after sleep and wake
* Account import
* Account export

Account fields:

* Friendly label
* SIP server
* Registrar
* Outbound proxy
* Username
* Authentication ID
* Password
* Domain
* Display name
* Dialing prefix
* Dial plan
* Voicemail number
* Transport
* Local SIP port
* Public address override
* STUN server
* TURN server
* TURN username
* TURN credential reference
* ICE
* Contact rewrite
* Via rewrite
* Registration interval
* Keepalive interval
* Session timers
* Presence publishing
* Caller-ID privacy
* Media-encryption policy
* TLS certificate policy
* Custom User-Agent
* Optional custom SIP headers

Store passwords and equivalent secrets in Keychain.

Persist only stable Keychain references in the application database.

Do not display an existing password in plaintext when editing an account.

## 2. Transport and SIP security

Support:

* UDP
* TCP
* TLS
* IPv4
* IPv6 where supported
* DNS resolution
* SIP URI host and port
* Outbound proxy
* SIP digest authentication
* System trust store
* TLS certificate verification
* TLS hostname verification
* Optional user-installed CA
* Visible insecure-certificate override, disabled by default
* SRTP optional
* SRTP mandatory
* DTLS-SRTP where supported
* Controlled secure-media fallback
* Redaction of SIP authentication data

Do not disable certificate validation for convenience.

## 3. Dialer

Support:

* Plain telephone number
* Extension
* E.164
* Formatted telephone number
* SIP URI
* SIPS URI
* Direct IP address
* Hostname
* Optional SIP port
* Display name with SIP URI
* URI parameters
* Custom outgoing headers
* Post-connect DTMF
* Dial-plan transformation
* Prefix application
* Dial-plan rejection
* Keyboard entry
* Paste
* Backspace
* Clear
* Redial
* Audio call
* Video call
* Voicemail
* Contact suggestions
* Recent-call suggestions

Do not strip meaningful SIP URI syntax while normalizing telephone numbers.

## 4. Incoming and outgoing calls

Implement:

* Incoming audio calls
* Outgoing audio calls
* Incoming video calls
* Outgoing video calls
* Ringing
* Early media
* Progress tones
* Provisional SIP responses
* Answer
* Reject
* Reject as busy
* Cancel outgoing call
* End call
* Remote hangup
* Call duration
* Caller and callee identity
* P-Asserted-Identity
* Remote-Party-ID
* Diversion and forwarded-call identity
* Call waiting
* Multiple simultaneous calls
* Configurable maximum calls
* Automatic rejection when maximum is reached
* Microphone mute
* Remote-output mute
* Hold
* Resume
* Swap
* Automatic hold during call switching
* Configurable auto-hangup
* Caller-ID privacy
* Detailed diagnostics

Provide understandable user states while preserving the raw SIP code in diagnostics.

At minimum map:

| SIP code | User-facing result              |
| -------: | ------------------------------- |
|      400 | Invalid request                 |
|      401 | Authentication required         |
|      403 | Call forbidden                  |
|      404 | Number or destination not found |
|      407 | Proxy authentication required   |
|      408 | Request timed out               |
|      480 | Temporarily unavailable         |
|      481 | Call no longer exists           |
|      486 | Busy                            |
|      487 | Call cancelled                  |
|      488 | Incompatible media              |
|      500 | Server error                    |
|      502 | Bad gateway                     |
|      503 | Service unavailable             |
|      600 | Busy                            |
|      603 | Call declined                   |

For SIP 404, use `Number not found` or `Destination not found`, not a generic `Call failed`.

## 5. DTMF

Support:

* RFC 4733/RFC 2833 events
* SIP INFO
* In-band DTMF
* Automatic selection
* Preferred-method setting
* On-screen keypad
* Keyboard DTMF
* Automatic post-connect sequence
* Comma-based pauses
* Optional DTMF suppression in logs

Treat DTMF as sensitive because it may contain PINs or payment information.

## 6. Call transfer

Implement:

* Blind transfer using REFER
* Attended transfer
* Consultation call
* Transfer cancellation
* Transfer failure
* Recovery to original call
* Feature-code fallback
* Configurable blind-transfer code
* Configurable attended-transfer code
* Transfer to:

  * typed destination
  * contact
  * recent destination
  * another active call

Create integration tests for success, rejection, timeout, and unsupported transfer behavior.

## 7. Conference

Implement:

* Local multi-party audio conference
* Add active call
* Dial new participant
* Remove participant
* End one participant
* End all
* Hold individual participant when supported
* Conference from compact mode
* Conference from Call Manager
* Auto-conference option
* Mixed conference recording
* Participant state display

Use the PJSIP conference bridge rather than implementing a custom audio mixer in Swift.

## 8. DND, auto-answer, and forwarding

### DND

Implement:

* Persistent toggle
* Configurable rejection behavior
* Missed-call history
* Optional notification

### Auto-answer

Implement:

* Enable/disable
* Configurable delay
* Caller-number rules
* Wildcards
* Multiple rules
* SIP-header-based activation
* Audible warning before microphone activation
* Visible active state

Recognize supported forms such as:

* `Call-Info: Auto Answer`
* `Call-Info: answer-after=N`
* `X-AUTOANSWER: TRUE`

Do not trust unverified headers across arbitrary untrusted networks without a configurable policy.

### Forwarding

Implement:

* Immediate forwarding
* Busy forwarding
* No-answer forwarding
* No-answer delay
* Standard SIP redirect where possible
* Feature-code fallback
* Target validation

Clearly document PBX-specific dependencies.

## 9. Audio media

Implement:

* Input-device selection
* Output-device selection
* Ring-device selection
* Follow system default
* Device-change detection
* Device-loss handling
* Device reconnection
* Microphone level
* Output level
* Optional software microphone gain
* Echo cancellation
* Voice activity detection
* Noise suppression where supported
* Automatic gain control when explicitly enabled
* Audio test
* Ringtone preview
* Custom ringtone
* Bluetooth headset support
* USB headset support
* Headset button handling where macOS exposes it
* Sensible no-microphone state
* Route-change recovery

Avoid changing global macOS volume when application-level gain is sufficient.

## 10. Audio codecs

Expose:

* Availability
* Enable/disable
* Priority
* Negotiated codec
* Codec-specific options where supported

Support when available, built, interoperable, and legally redistributable:

* Opus
* PCMU
* PCMA
* G.722
* Speex
* iLBC
* GSM
* G.723 where appropriate
* G.729 only with a properly licensed implementation
* AMR/AMR-WB only when licensing permits
* SILK only when legally and technically available

Do not represent unavailable codecs as enabled.

## 11. Call-quality statistics

Display:

* Audio codec
* Video codec
* Packet loss
* Jitter
* Round-trip time
* Sent packets
* Received packets
* Discarded packets
* Bitrate
* Quality estimate where supported
* SRTP status
* DTLS status
* ICE status
* Selected ICE candidate pair

Provide:

* Compact green/amber/red quality summary
* Detailed popover
* Clear unavailable state
* No fabricated values

## 12. Recording

Implement:

* Start recording
* Stop recording
* Recording indicator
* Recording directory
* Per-call recording
* Conference recording
* Hold behavior
* Collision-safe filenames
* Sanitized identifiers
* Recording metadata
* Failure notification
* Disk-space errors
* Permission errors
* Open recording from history

Use WAV as a safe default unless another format is fully justified.

Add AAC/M4A using native APIs if appropriate.

Do not add MP3 encoding without verifying implementation and redistribution terms.

Provide a configurable recording-consent notice.

## 13. Video

Implement real video calling.

Support where compiled, available, interoperable, and redistributable:

* H.264
* H.263/H.263+
* VP8
* VP9

Provide:

* Camera selection
* Permission handling
* Local preview
* Remote video
* Add video to audio call
* Remove video without ending audio
* Resolution
* Frame rate
* Bitrate
* Aspect-fit display
* Picture-in-picture local preview
* Camera-loss handling
* No-camera state
* Hardware acceleration where reliable
* Efficient native rendering

Do not infer runtime codec availability from API declarations alone.

## 14. SIP messaging

Implement SIP MESSAGE support:

* Send
* Receive
* Conversation grouping
* Timestamps
* Sent state
* Failed state
* Received state
* Multiple conversations
* Notifications
* Disable-messaging setting
* Plain-text rendering
* Safe URL handling
* Persistence
* Delete conversation
* UTF-8
* Right-to-left text

Do not execute HTML or scripts from received messages.

## 15. Contacts

Implement local contacts with:

* Name
* Primary SIP identity
* Multiple telephone numbers
* Phone
* Mobile
* Email
* Address
* City
* State
* Postal code
* Comment
* Additional information
* Presence enabled
* Favorite status
* Search
* Sorting
* Add
* Edit
* Delete
* Duplicate handling
* Call action
* Message action
* Number selection
* Import
* Export

Add optional read-only integration with macOS Contacts.

Request Contacts permission only when the feature is enabled.

Do not upload contacts.

## 16. Presence, BLF, and pickup

Implement:

* SUBSCRIBE
* NOTIFY
* PUBLISH when enabled
* Online
* Offline
* Away
* Busy
* Ringing
* On call
* Unknown
* Subscription refresh
* Recovery after registration changes
* Recovery after network changes
* Contact presence indicators
* BLF shortcut buttons
* Directed pickup
* Configurable pickup prefix
* Clear PBX dependency documentation

## 17. External directory

Implement HTTPS directory retrieval.

Support:

* JSON
* XML
* Cisco IP Phone directory format where practical
* Common Yealink-style data where practical
* UTF-8
* Sequence parameter
* Refresh interval
* Manual refresh
* Exponential backoff
* Optional suppression of repeated errors
* Presence-only updates
* Local cache
* Source indicator
* Request timeout
* Response-size limit
* Parser-depth and entity limits
* TLS validation

Do not support XML external entities.

Do not log authorization headers or tokens.

## 18. Call history

Persist:

* Direction
* Incoming
* Outgoing
* Missed
* Rejected
* Forwarded
* Failed
* Answered
* Start time
* Answer time
* End time
* Ring duration
* Talk duration
* Total duration
* Remote identity
* Resolved contact
* SIP URI
* Account
* Final SIP code
* User-facing outcome
* Audio codec
* Video codec
* Encryption state
* Recording reference
* Quality summary

Provide:

* Search
* Date grouping
* Direction filter
* Result filter
* Redial
* Add to contacts
* Copy
* Open recording
* Delete entry
* Clear history with confirmation
* CSV export
* JSON export
* Import of the application’s own export format

Answered calls must show talk duration.

Unanswered and failed calls should show their result instead of a meaningless zero duration.

## 19. Programmable shortcuts

Support shortcut definitions containing:

* Label
* Primary action
* Secondary action
* Toggle state
* BLF
* Presence
* Audio call
* Video call
* DTMF
* Pickup
* Blind transfer
* Attended-transfer feature code
* Hold
* Resume
* Mute
* DND
* Forwarding
* Auto-answer
* Open URL
* Local executable action

Local executable actions must be:

* Disabled by default
* Explicitly approved
* Represented as executable path plus argument array
* Free from shell-string concatenation
* Visible to the user before enabling
* Unable to receive SIP passwords
* Logged only with redacted metadata

## 20. Automation and local control

Expose typed events for:

* Call started
* Call connected
* Incoming call
* Incoming call answered
* Call ended
* Registration changed
* Message received
* Presence changed

Support URL schemes:

* `sip:`
* `sips:`
* `tel:`
* `macsip:`

Provide local command or CLI operations:

* Dial
* Dial audio
* Dial video
* Answer
* Reject
* Hang up all
* Hang up incoming
* Hang up outgoing
* Transfer
* Send DTMF
* Show application
* Select account
* Print status as JSON
* Reset data with confirmation

Use secure local IPC such as:

* XPC
* A permission-controlled Unix domain socket
* Another authenticated local mechanism

Do not expose an unauthenticated network control port.

## 21. Import and export

Provide versioned import/export for:

* Accounts without plaintext secrets by default
* Settings
* Contacts
* Shortcuts
* History
* Codec priority
* Directory settings

For optional encrypted credential export:

* Require explicit opt-in
* Require a passphrase
* Use a modern password-based key derivation function
* Use authenticated encryption
* Document format and parameters
* Never persist or log the passphrase

Include:

* Schema validation
* Import preview
* Conflict resolution
* Transactional application
* Rollback on failure

## 22. Settings

Create native settings sections:

* General
* Accounts
* Audio
* Video
* Calls
* Codecs
* Network
* Security
* Presence
* Contacts and Directory
* Shortcuts
* Recording
* Notifications
* Automation
* Advanced
* Diagnostics
* About

Include:

* Compact mode
* Call Manager mode
* Start at login
* Hide to menu bar
* Show Dock icon
* Always-on-top incoming panel
* System/light/dark appearance
* Ringtone
* Sound events
* Auto-answer
* Forwarding
* DND
* Incoming-call filters
* Maximum calls
* Media keys
* Headset integration
* Logging level
* Log rotation
* Crash reporting opt-in
* Update checking opt-in
* Reset application

## 23. Diagnostics

Create diagnostics showing:

* App version
* Build number
* macOS version
* CPU architecture
* PJSIP version
* Compiled codecs
* Runtime codecs
* Available transports
* TLS backend
* Active account
* Registration state
* Sanitized registrar
* Sanitized proxy
* Network interfaces
* Selected addresses
* STUN result
* ICE state
* Audio devices
* Video devices
* Recent registration failures
* Recent call failures
* Active-call statistics

Provide sanitized diagnostic export.

Exclude:

* Passwords
* Digest responses
* Authorization headers
* Private keys
* Keychain data
* Message bodies by default
* Contacts by default
* Complete DTMF sequences
* Recordings
* Directory credentials
* Unredacted private URLs

Add automated redaction tests.

# Minimalist macOS UI

The UI must be original but should preserve MicroSIP’s compact desktop-utility character.

## General design

Use:

* Native macOS typography
* Restrained visual hierarchy
* Compact spacing
* SF Symbols or original vectors
* System materials only where useful
* Clear status indicators
* Keyboard focus
* Context menus
* Tooltips
* Proper disabled states
* Light and dark modes

Avoid:

* Gradients
* Marketing-style hero areas
* Oversized headings
* Excessive cards
* Mobile bottom navigation
* Huge rounded containers
* Decorative animation
* Excessive whitespace
* Unnecessary full-screen workflows

Target an initial main-window size near:

* Width: 340–380 points
* Height: 520–620 points

## Main window header

Include:

* Registration indicator
* Active account
* Account selector
* Settings/menu control
* Registration error summary

## Primary navigation

Use a compact segmented control or tabs:

* Dialpad
* Calls
* Contacts

Messaging may appear in Call Manager conversation tabs rather than permanently occupying primary navigation.

## Dialpad

Include:

* Number/SIP URI field
* Contact/recent suggestion
* 3×4 keypad
* Audio-call button
* Video-call button
* Backspace
* Redial
* Voicemail
* Compact status footer
* DND indicator/control
* Forwarding indicator/control
* Auto-answer indicator/control
* Auto-conference indicator/control

## Call history

Rows should show:

* Direction
* Contact or number
* Date/time
* Talk duration for answered calls
* Outcome for unanswered calls
* Recording indicator
* Encryption indicator where useful

Support double-click redial and context menus.

## Contacts

Include:

* Search
* Favorites
* Presence
* Name
* Primary identity
* Add/edit
* Call
* Message
* Context menu

## Active call

Show:

* Remote name
* Remote identity
* Call state
* Duration
* Quality
* Encryption
* Mute
* Hold/resume
* Keypad
* Transfer
* Add/conference
* Record
* Video
* End

## Call Manager

Provide advanced multiple-session management:

* One tab per remote session
* Multiple calls
* Associated messages
* Auto hold/resume on tab switch
* Blind transfer
* Attended transfer
* Conference
* Last-call navigation
* Safe tab close behavior
* Safe window close behavior

## Incoming-call panel

Provide a compact floating panel:

* Caller
* Number/SIP URI
* Receiving account
* Forwarding information
* Audio/video indication
* Answer
* Decline
* Busy
* Keyboard shortcuts
* VoiceOver labels
* Multi-monitor-safe placement
* Notification fallback

Do not randomly reposition the window by default.

## Menu bar

Provide:

* Registration state
* Account
* Active calls
* DND
* Show/hide
* Dial
* Answer
* Hang up
* Mute
* Hold
* Recent calls
* Settings
* Quit

Quitting with active calls must warn or follow an explicit configured policy.

# macOS integration

Implement:

* Microphone permission
* Camera permission
* Contacts permission only when enabled
* Notification permission
* Launch at login
* Sleep/wake handling
* Network-change handling
* VPN interface changes
* Audio-device changes
* Camera-device changes
* Multiple monitors
* Retina display
* Light/dark appearance
* VoiceOver
* Full keyboard navigation
* Reduced motion
* Native menu commands
* Standard settings shortcut
* Standard reopen behavior
* Hardened Runtime compatibility
* Developer ID signing
* Notarization
* DMG or ZIP packaging

Do not claim Mac App Store support unless sandboxing and App Store restrictions are specifically tested.

# Persistence

Persist non-secret data through repositories.

Required repositories:

* Accounts
* Contacts
* Presence cache
* Calls
* Messages
* Settings
* Shortcuts
* Recording metadata
* Directory cache

Requirements:

* Versioned schema
* Tested migrations
* Transactional import
* Referential integrity
* No password columns
* Bounded retention
* Corruption handling
* Backup and restore documentation

# Security

Create `THREAT_MODEL.md`.

Cover:

* SIP credential theft
* Malformed SIP messages
* SIP URI injection
* Log leakage
* TLS downgrade
* Certificate bypass
* Malicious directory data
* Malicious import files
* Command injection
* Local IPC abuse
* Recording leakage
* Database leakage
* Path traversal
* Symlink attacks
* Oversized messages
* XML attacks
* Call/message denial of service
* Caller-ID spoofing
* Untrusted asserted identity
* Dependency compromise
* Update compromise
* Objective-C++ memory-safety errors
* Use-after-free during callbacks
* Race conditions during shutdown

Secure defaults:

* Keychain secrets
* TLS validation enabled
* No executable hooks
* No analytics
* Crash reporting opt-in
* Update checking opt-in
* DTMF redaction
* Message redaction
* Bounded inputs
* Sanitized filenames
* Strict imports
* No automatic URL opening
* No execution of received content

# Testing

## Unit tests

Cover:

* SIP URI parsing
* Telephone normalization
* Dial plans
* Account validation
* Keychain references
* Registration states
* Incoming calls
* Outgoing calls
* Early media
* Hold/resume
* Multiple calls
* Blind transfer
* Attended transfer
* Conference membership
* DTMF sequences
* Caller wildcard rules
* Auto-answer rules
* SIP status mapping
* Call durations
* Contact deduplication
* Presence mapping
* JSON directory parsing
* XML directory parsing
* Import validation
* Database migrations
* Codec priority
* Filename sanitization
* Log redaction
* Diagnostic redaction
* Executable argument construction
* Recording metadata

## Integration tests

Include a reproducible test environment using Asterisk or FreeSWITCH.

Provide at least:

* Three extensions
* UDP
* TCP
* TLS
* SRTP
* Voicemail
* Blind transfer
* Attended transfer
* Conference
* Presence
* BLF
* Pickup
* SIP MESSAGE
* Auto-answer headers
* Forwarding
* Common failure responses

Include SIPp scenarios for:

* Registration success
* Authentication challenge
* Wrong password
* 404
* 486
* 408/timeout
* Incoming call
* Cancel
* Early media
* DTMF
* Re-registration
* Network interruption
* Malformed input
* Repeated messages
* Transfer success
* Transfer failure

Never use customer credentials.

## Media verification

Do not treat SIP 200 OK as proof that a call works.

Verify:

* RTP sent
* RTP received
* Bidirectional audible test media
* Correct codec
* DTMF delivery
* Hold behavior
* SRTP state
* Recording output
* Conference mixing

Use generated test tones or audio fixtures where appropriate.

## UI tests

Cover:

* First launch
* Permission denial
* Add account
* Registration success
* Registration failure
* Dial
* Receive
* Active-call controls
* History
* Contacts
* Settings
* Dark mode
* Keyboard navigation
* Accessibility identifiers
* Import
* Export

## Interoperability matrix

Create `docs/INTEROP_TEST_MATRIX.md` covering:

* Asterisk
* FreeSWITCH
* Kamailio/OpenSIPS with media infrastructure
* Hosted PBX behavior
* UDP
* TCP
* TLS
* SRTP
* DTLS-SRTP
* NAT
* TURN
* VPN
* IPv6
* Apple Silicon
* Intel
* Built-in audio
* USB headset
* Bluetooth headset

Mark each item:

* Not tested
* Pass
* Partial
* Fail
* Blocked

Do not claim untested interoperability.

# Performance

Targets:

* No SIP work on the main thread
* Near-zero idle CPU after registration stabilizes
* No unnecessary polling
* Bounded memory
* No growth over repeated call cycles
* Immediate control response
* Efficient lists
* Efficient video rendering
* Bounded logs
* Clean shutdown

Document Instruments procedures for:

* Leaks
* Allocations
* Time Profiler
* Energy Log
* Thread Sanitizer
* Address Sanitizer
* Undefined Behavior Sanitizer where compatible

# CI

Create CI workflows that:

* Build from a clean checkout
* Verify dependency checksums
* Build Debug
* Build Release
* Run unit tests
* Run practical integration tests
* Run static analysis
* Check formatting
* Scan for secrets
* Validate license notices
* Archive test artifacts
* Produce readable reports

Avoid introducing a third-party dependency when Apple frameworks or a small tested component are sufficient.

# Documentation

Create:

* `README.md`
* `CLAUDE.md`
* `ARCHITECTURE.md`
* `PARITY_MATRIX.md`
* `THREAT_MODEL.md`
* `BUILDING.md`
* `CONTRIBUTING.md`
* `SECURITY.md`
* `LICENSE`
* `DEPENDENCY_LICENSES.md`
* `THIRD_PARTY_NOTICES.md`
* `docs/RESEARCH_BASELINE.md`
* `docs/CLEAN_ROOM_PROCESS.md`
* `docs/SIP_STATE_MACHINES.md`
* `docs/PJSIP_INTEGRATION.md`
* `docs/INTEROP_TEST_MATRIX.md`
* `docs/TEST_PBX.md`
* `docs/RELEASING.md`
* `docs/PRIVACY.md`
* `docs/KNOWN_LIMITATIONS.md`

The README must state the real implementation status and must not imply that incomplete functions are available.

# Parity tracking

Create `PARITY_MATRIX.md`.

For every feature record:

* Feature
* MicroSIP reference
* MacSIP implementation status
* Relevant source files
* Unit-test status
* Integration-test status
* Manual-test status
* PBX dependency
* Known limitations
* Last verified date

Allowed statuses:

* Not researched
* Researched
* Not started
* In progress
* Implemented
* Unit tested
* Integration tested
* Manually verified
* Blocked
* Not applicable

Never mark a feature complete based only on a compiled interface.

# Milestones

## Milestone 0 — research and foundation

Deliver:

* Research baseline
* Licensing review
* Clean-room process
* `CLAUDE.md`
* Project settings
* Useful subagents
* Useful skills
* Threat model
* Architecture
* Parity matrix
* Xcode project
* CI
* Reproducible PJSIP build

## Milestone 1 — real audio-call vertical slice

Deliver a working:

* Account form
* Keychain password
* UDP registration
* Registration status
* Outgoing audio call
* Incoming audio call
* Answer
* Reject
* Microphone
* Speaker
* Mute
* Hold/resume
* DTMF
* Hangup
* Basic history
* Basic diagnostics
* Unit tests
* PBX integration tests

Do not prioritize extensive visual polish before this vertical slice works with real media.

## Milestone 2 — account, network, and security maturity

Deliver:

* Multiple accounts
* Account switching
* TCP
* TLS
* Certificate validation
* SRTP
* DTLS-SRTP where available
* STUN
* TURN
* ICE
* Network recovery
* Sleep/wake recovery
* Detailed errors

## Milestone 3 — complete compact GUI

Deliver:

* Dialpad
* Calls
* Contacts
* Incoming-call panel
* Active-call UI
* Menu bar
* Dark mode
* Accessibility
* Keyboard controls
* Launch at login

## Milestone 4 — advanced calling

Deliver:

* Multiple calls
* Call Manager
* Blind transfer
* Attended transfer
* Conference
* DND
* Forwarding
* Auto-answer
* Auto-conference
* Recording
* Call-quality statistics

## Milestone 5 — contacts and presence

Deliver:

* Local contacts
* Import/export
* macOS Contacts
* Presence
* BLF
* Pickup
* External directory
* Shortcuts

## Milestone 6 — messaging and video

Deliver:

* SIP messaging
* Camera management
* Video calling
* Local preview
* Remote video
* Codec configuration
* Video interoperability tests

## Milestone 7 — automation and release readiness

Deliver:

* URL schemes
* Local CLI
* Secure IPC
* Event hooks
* Full import/export
* Diagnostic bundles
* Signing
* Hardened Runtime
* Notarization
* Packaging
* Performance review
* Security review
* Release documentation

# Acceptance criteria

The project is not complete until applicable criteria are satisfied:

1. A fresh clone can bootstrap dependencies using documented commands.
2. PJSIP builds reproducibly.
3. The app builds for arm64.
4. The app builds for x86_64 unless a verified dependency limitation prevents it.
5. No secrets are committed.
6. Passwords are stored in Keychain.
7. The app registers against the included test PBX.
8. Bidirectional audio is verified.
9. Incoming calls work.
10. Outgoing calls work.
11. Mute works.
12. Hold/resume works.
13. DTMF works.
14. Multiple calls work.
15. Blind transfer works.
16. Attended transfer works.
17. Conference works.
18. SIP messaging works.
19. Presence and BLF work against the test PBX.
20. Recording creates a playable file.
21. History records direction, outcome, timestamps, and talk duration.
22. SIP 404 displays destination or number not found.
23. TLS validates certificates.
24. Media encryption state is visible.
25. Network changes recover registration.
26. Sleep/wake does not corrupt the runtime.
27. Repeated call cycles do not freeze or leak continuously.
28. Logs do not contain credentials.
29. Unit tests pass.
30. Integration tests pass or contain documented environment-dependent skips.
31. A clean Release build passes.
32. The interface remains compact.
33. Keyboard navigation works.
34. VoiceOver labels exist.
35. The parity matrix accurately reflects actual verification.
36. `/review` findings have been resolved or documented.
37. `/security-review` findings have been resolved or documented.
38. The final repository has no misleading placeholder implementations.

# Implementation behavior

For every feature:

1. Research the relevant behavior.
2. Update or confirm the design.
3. Add or update the state machine.
4. Add domain models.
5. Implement the PJSIP bridge.
6. Implement persistence if needed.
7. Implement UI.
8. Add structured redacted logs.
9. Add unit tests.
10. Add integration tests.
11. Build.
12. Run tests.
13. Review the diff.
14. Update documentation.
15. Update the parity matrix.
16. Commit a logical checkpoint when appropriate.

Do not implement dozens of untested stubs in parallel.

Prefer complete vertical slices.

# Failure handling

When blocked:

* Do not fabricate success.
* Record the exact error.
* Record the command that produced it.
* Identify whether the cause is:

  * source code
  * environment
  * missing dependency
  * license restriction
  * unavailable credential
  * signing requirement
  * PBX limitation
  * platform limitation
* Implement all remaining unblocked work.
* Add a minimal reproduction where useful.
* Document a specific next action.

Do not stop the entire project because one optional codec, signing credential, or service is unavailable.

# Final session report

At the end of each session, report:

1. Implementation slice attempted
2. Files created
3. Files modified
4. Architecture decisions
5. Features completed
6. Tests added
7. Commands executed
8. Exact build result
9. Exact test result
10. Review findings
11. Security findings
12. Licensing findings
13. Known failures
14. Parity-matrix changes
15. Git status
16. Next highest-priority vertical slice

Do not merely describe how this application could be built.

Inspect the repository, create the project, write the implementation, compile it, run tests, inspect failures, fix defects, and leave the repository in a truthful, reviewable, and buildable state.
