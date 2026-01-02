import Foundation

/// Handles distributed notifications between companion app and screensaver
/// Uses CFNotificationCenter for cross-process communication
class NotificationBridge {
    static let shared = NotificationBridge()

    // MARK: - Notification Names

    /// Notification name prefix
    private let prefix = "org.electricsheep."

    // Outgoing (Companion → Screensaver)
    private var pongName: CFString { "\(prefix)ESPong" as CFString }
    private var companionLaunchedName: CFString { "\(prefix)ESCompanionLaunched" as CFString }
    private var cacheUpdatedName: CFString { "\(prefix)ESCacheUpdated" as CFString }
    private var voteFeedbackName: CFString { "\(prefix)ESVoteFeedback" as CFString }
    private var queryCurrentName: CFString { "\(prefix)ESQueryCurrent" as CFString }

    // Incoming (Screensaver → Companion)
    private var pingName: CFString { "\(prefix)ESPing" as CFString }
    private var sheepPlayingName: CFString { "\(prefix)ESSheepPlaying" as CFString }
    private var playbackStartedName: CFString { "\(prefix)ESPlaybackStarted" as CFString }
    private var corruptedFileName: CFString { "\(prefix)ESCorruptedFile" as CFString }

    // MARK: - State

    private var isListening = false
    private var pendingVoteQuery: ((String?) -> Void)?

    private init() {}

    // MARK: - Start/Stop

    func startListening() {
        guard !isListening else { return }
        isListening = true

        let center = CFNotificationCenterGetDistributedCenter()

        // Register for incoming notifications
        registerObserver(center, name: pingName, callback: handlePing)
        registerObserver(center, name: sheepPlayingName, callback: handleSheepPlaying)
        registerObserver(center, name: playbackStartedName, callback: handlePlaybackStarted)
        registerObserver(center, name: corruptedFileName, callback: handleCorruptedFile)

        print("NotificationBridge: Started listening for screensaver notifications")
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false

        let center = CFNotificationCenterGetDistributedCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())

        print("NotificationBridge: Stopped listening")
    }

    // MARK: - Outgoing Notifications

    /// Broadcast that companion has launched
    func broadcastCompanionLaunched() {
        // Include capabilities in the notification name suffix
        let capabilities = "voting=1,rendering=0,gold=0"
        let name = "\(prefix)ESCompanionLaunched.\(capabilities)" as CFString
        postNotification(name: name)
        print("NotificationBridge: Broadcast companion launched with capabilities: \(capabilities)")
    }

    /// Respond to ping from screensaver
    func sendPong() {
        postNotification(name: pongName)
    }

    /// Notify screensaver that cache was updated
    func broadcastCacheUpdated() {
        postNotification(name: cacheUpdatedName)
        print("NotificationBridge: Broadcast cache updated")
    }

    /// Send vote feedback to screensaver
    func sendVoteFeedback(direction: VoteDirection) {
        let name = "\(prefix)ESVoteFeedback.\(direction.rawValue)" as CFString
        postNotification(name: name)
    }

    /// Query screensaver for currently playing sheep
    func queryCurrentSheep(completion: @escaping (String?) -> Void) {
        pendingVoteQuery = completion

        postNotification(name: queryCurrentName)

        // Timeout after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if let pending = self?.pendingVoteQuery {
                self?.pendingVoteQuery = nil
                pending(nil)
            }
        }
    }

    // MARK: - Incoming Handlers

    private func handlePing() {
        print("NotificationBridge: Received ping from screensaver")
        sendPong()
    }

    private func handleSheepPlaying(payload: String?) {
        guard let sheepID = payload else { return }
        print("NotificationBridge: Screensaver playing sheep: \(sheepID)")

        // If we have a pending vote query, fulfill it
        if let completion = pendingVoteQuery {
            pendingVoteQuery = nil
            completion(sheepID)
        }
    }

    private func handlePlaybackStarted(payload: String?) {
        guard let sheepID = payload else { return }
        print("NotificationBridge: Playback started for sheep: \(sheepID)")

        // Update LRU timestamp
        CacheManager.shared.updatePlaybackTime(sheepID: sheepID)
    }

    private func handleCorruptedFile(payload: String?) {
        guard let sheepID = payload else { return }
        print("NotificationBridge: Corrupted file reported: \(sheepID)")

        // Mark for re-download with high priority
        // TODO: Implement priority re-download
    }

    // MARK: - Helpers

    private func postNotification(name: CFString) {
        let center = CFNotificationCenterGetDistributedCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(name), nil, nil, true)
    }

    private func registerObserver(_ center: CFNotificationCenter?,
                                   name: CFString,
                                   callback: @escaping () -> Void) {
        // Store callback for later
        let context = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(
            center,
            context,
            { (_, observer, name, _, _) in
                guard let observer = observer else { return }
                let bridge = Unmanaged<NotificationBridge>.fromOpaque(observer).takeUnretainedValue()
                bridge.dispatchNotification(name: name)
            },
            name,
            nil,
            .deliverImmediately
        )
    }

    private func registerObserver(_ center: CFNotificationCenter?,
                                   name: CFString,
                                   callback: @escaping (String?) -> Void) {
        registerObserver(center, name: name) { [weak self] in
            // For notifications with payloads, we use name suffix
            // e.g., "ESPlaybackStarted.248=12345=0=240"
            callback(nil)
        }
    }

    private func dispatchNotification(name: CFNotificationName?) {
        guard let name = name?.rawValue as String? else { return }

        // Extract payload from name suffix if present
        let parts = name.components(separatedBy: ".")
        let baseName = parts.dropLast().joined(separator: ".")
        let payload = parts.count > 2 ? parts.last : nil

        switch baseName {
        case String(pingName):
            handlePing()
        case String(sheepPlayingName).replacingOccurrences(of: ".\(payload ?? "")", with: ""):
            handleSheepPlaying(payload: payload)
        case String(playbackStartedName).replacingOccurrences(of: ".\(payload ?? "")", with: ""):
            handlePlaybackStarted(payload: payload)
        case String(corruptedFileName).replacingOccurrences(of: ".\(payload ?? "")", with: ""):
            handleCorruptedFile(payload: payload)
        default:
            // Check if it's a notification with suffix
            if name.hasPrefix("\(prefix)ESSheepPlaying") {
                let sheepID = name.replacingOccurrences(of: "\(prefix)ESSheepPlaying.", with: "")
                handleSheepPlaying(payload: sheepID)
            } else if name.hasPrefix("\(prefix)ESPlaybackStarted") {
                let sheepID = name.replacingOccurrences(of: "\(prefix)ESPlaybackStarted.", with: "")
                handlePlaybackStarted(payload: sheepID)
            } else if name.hasPrefix("\(prefix)ESCorruptedFile") {
                let sheepID = name.replacingOccurrences(of: "\(prefix)ESCorruptedFile.", with: "")
                handleCorruptedFile(payload: sheepID)
            } else if name.hasPrefix("\(prefix)ESPing") {
                handlePing()
            }
        }
    }
}

enum VoteDirection: String {
    case up
    case down
}
