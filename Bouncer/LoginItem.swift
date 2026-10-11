import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = false

    init() {
        refresh()
    }

    /// The user can change this in System Settings too, so re-read it whenever the panel opens.
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Couldn't change login item: \(error)")
        }

        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
    }
}
