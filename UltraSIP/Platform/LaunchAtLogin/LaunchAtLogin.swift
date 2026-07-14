import ServiceManagement

/// Launch at login via SMAppService (macOS 13+ API; SMLoginItemSetEnabled
/// is deprecated — RESEARCH_BASELINE §5).
///
/// Note: registration only succeeds for a signed, bundled app; ad-hoc dev
/// builds may report `.requiresApproval` or fail until the user approves
/// the item in System Settings → General → Login Items.
nonisolated enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
