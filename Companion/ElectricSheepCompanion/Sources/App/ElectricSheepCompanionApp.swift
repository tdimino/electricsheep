import SwiftUI

@main
struct ElectricSheepCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services
        CacheManager.shared.ensureDirectoryStructure()
        NotificationBridge.shared.startListening()
        VoteManager.shared.registerHotkeys()

        // Set up menu bar
        menuBarController = MenuBarController()

        // Broadcast that companion is running
        NotificationBridge.shared.broadcastCompanionLaunched()

        // Submit any queued offline votes
        VoteManager.shared.submitOfflineVotes()

        // Start downloading sheep
        DownloadManager.shared.startSync()
    }

    func applicationWillTerminate(_ notification: Notification) {
        VoteManager.shared.unregisterHotkeys()
        NotificationBridge.shared.stopListening()
    }
}
