import SwiftUI
import Sparkle

@main
struct BouncerApp: App {
    @StateObject private var store = VolumeStore()
    @StateObject private var loginItem = LoginItem()

    // Unit tests run inside the app, and shouldn't go checking for updates.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        MenuBarExtra("Bouncer", image: "MenuBarIcon") {
            MenuContentView(store: store, loginItem: loginItem, updater: updaterController.updater)
        }
        .menuBarExtraStyle(.window)
    }
}
