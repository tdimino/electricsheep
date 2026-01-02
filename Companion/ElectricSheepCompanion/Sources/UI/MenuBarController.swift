import AppKit
import SwiftUI

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var preferencesWindow: NSWindow?

    override init() {
        super.init()
        setupStatusItem()
        setupMenu()

        // Observe download progress
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenu),
            name: .downloadProgressChanged,
            object: nil
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = createCloudSyncIcon()
            button.image?.isTemplate = true
            button.imagePosition = .imageLeft
            updateBadge()
        }
    }

    /// Create cloud-sync icon from Iconoir (https://iconoir.com)
    private func createCloudSyncIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let scale: CGFloat = 18.0 / 24.0
            let transform = NSAffineTransform()
            transform.scale(by: scale)
            transform.concat()

            NSColor.black.setStroke()

            // Cloud path
            let cloudPath = NSBezierPath()
            cloudPath.move(to: NSPoint(x: 20, y: 24 - 17.6073))
            cloudPath.curve(to: NSPoint(x: 23, y: 24 - 13),
                           controlPoint1: NSPoint(x: 21.4937, y: 24 - 17.0221),
                           controlPoint2: NSPoint(x: 23, y: 24 - 15.6889))
            cloudPath.curve(to: NSPoint(x: 18, y: 24 - 8),
                           controlPoint1: NSPoint(x: 23, y: 24 - 9),
                           controlPoint2: NSPoint(x: 19.6667, y: 24 - 8))
            cloudPath.curve(to: NSPoint(x: 12, y: 24 - 2),
                           controlPoint1: NSPoint(x: 18, y: 24 - 6),
                           controlPoint2: NSPoint(x: 18, y: 24 - 2))
            cloudPath.curve(to: NSPoint(x: 6, y: 24 - 8),
                           controlPoint1: NSPoint(x: 6, y: 24 - 2),
                           controlPoint2: NSPoint(x: 6, y: 24 - 6))
            cloudPath.curve(to: NSPoint(x: 1, y: 24 - 13),
                           controlPoint1: NSPoint(x: 4.33333, y: 24 - 8),
                           controlPoint2: NSPoint(x: 1, y: 24 - 9))
            cloudPath.curve(to: NSPoint(x: 4, y: 24 - 17.6073),
                           controlPoint1: NSPoint(x: 1, y: 24 - 15.6889),
                           controlPoint2: NSPoint(x: 2.50628, y: 24 - 17.0221))
            cloudPath.lineWidth = 2.0
            cloudPath.lineCapStyle = .round
            cloudPath.lineJoinStyle = .round
            cloudPath.stroke()

            // Sync arrows (simplified)
            let arrowPath = NSBezierPath()
            arrowPath.move(to: NSPoint(x: 8, y: 24 - 18))
            arrowPath.line(to: NSPoint(x: 12, y: 24 - 14))
            arrowPath.move(to: NSPoint(x: 12, y: 24 - 22))
            arrowPath.line(to: NSPoint(x: 16, y: 24 - 18))
            arrowPath.lineWidth = 2.0
            arrowPath.lineCapStyle = .round
            arrowPath.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }

    private func setupMenu() {
        menu = NSMenu()

        // Sheep count header
        let countItem = NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")
        countItem.tag = 100
        menu.addItem(countItem)

        // Download status
        let downloadItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        downloadItem.tag = 101
        downloadItem.isHidden = true
        menu.addItem(downloadItem)

        menu.addItem(NSMenuItem.separator())

        // Pause/Resume syncing
        let pauseItem = NSMenuItem(title: "Pause Syncing", action: #selector(toggleSync), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.tag = 102
        menu.addItem(pauseItem)

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(title: "About Electric Sheep", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateBadge() {
        let count = CacheManager.shared.sheepCount
        if let button = statusItem.button {
            button.title = count > 0 ? " \(count)" : ""
        }
    }

    @objc private func updateMenu() {
        DispatchQueue.main.async { [weak self] in
            self?.updateBadge()
            self?.updateDownloadStatus()
        }
    }

    private func updateDownloadStatus() {
        guard let countItem = menu.item(withTag: 100),
              let downloadItem = menu.item(withTag: 101) else { return }

        let count = CacheManager.shared.sheepCount
        countItem.title = "\(count) sheep"

        let state = DownloadManager.shared.state
        switch state {
        case .idle:
            downloadItem.isHidden = true
        case .downloading(let current, let total):
            downloadItem.isHidden = false
            downloadItem.title = "Downloading \(current) of \(total)..."
        case .paused:
            downloadItem.isHidden = false
            downloadItem.title = "Syncing paused"
        case .error(let message):
            downloadItem.isHidden = false
            downloadItem.title = "Error: \(message)"
        }
    }

    @objc private func toggleSync() {
        guard let pauseItem = menu.item(withTag: 102) else { return }

        if DownloadManager.shared.isPaused {
            DownloadManager.shared.resume()
            pauseItem.title = "Pause Syncing"
        } else {
            DownloadManager.shared.pause()
            pauseItem.title = "Resume Syncing"
        }
    }

    @objc private func openPreferences() {
        if preferencesWindow == nil {
            let prefsView = PreferencesView()
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow?.title = "Electric Sheep Preferences"
            preferencesWindow?.contentView = NSHostingView(rootView: prefsView)
            preferencesWindow?.center()
            preferencesWindow?.isReleasedWhenClosed = false
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let downloadProgressChanged = Notification.Name("ESDownloadProgressChanged")
    static let cacheUpdated = Notification.Name("ESCacheUpdated")
}
