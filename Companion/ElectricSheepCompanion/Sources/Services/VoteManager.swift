import Foundation
import Carbon

/// Manages voting on sheep via global hotkeys
/// Uses Carbon API for hotkey registration (works in fullscreen)
class VoteManager {
    static let shared = VoteManager()

    private var upHotkeyRef: EventHotKeyRef?
    private var downHotkeyRef: EventHotKeyRef?

    private let session: URLSession
    private let voteBaseURL = "https://v3d0.sheepserver.net/cgi/vote.cgi"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    // MARK: - Hotkey Registration

    func registerHotkeys() {
        // Install Carbon event handler
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventSpec, nil, nil)

        // Register Cmd+Up for vote up
        var upHotkeyID = EventHotKeyID(signature: OSType(0x4553_5550), id: 1) // "ESUP"
        RegisterEventHotKey(UInt32(kVK_UpArrow),
                           UInt32(cmdKey),
                           upHotkeyID,
                           GetApplicationEventTarget(),
                           0,
                           &upHotkeyRef)

        // Register Cmd+Down for vote down
        var downHotkeyID = EventHotKeyID(signature: OSType(0x4553_444E), id: 2) // "ESDN"
        RegisterEventHotKey(UInt32(kVK_DownArrow),
                           UInt32(cmdKey),
                           downHotkeyID,
                           GetApplicationEventTarget(),
                           0,
                           &downHotkeyRef)

        print("VoteManager: Registered global hotkeys (Cmd+Up, Cmd+Down)")
    }

    func unregisterHotkeys() {
        if let ref = upHotkeyRef {
            UnregisterEventHotKey(ref)
            upHotkeyRef = nil
        }
        if let ref = downHotkeyRef {
            UnregisterEventHotKey(ref)
            downHotkeyRef = nil
        }
        print("VoteManager: Unregistered global hotkeys")
    }

    // MARK: - Vote Handling

    func handleVote(direction: VoteDirection) {
        print("VoteManager: Vote \(direction.rawValue) triggered")

        // Query screensaver for current sheep
        NotificationBridge.shared.queryCurrentSheep { [weak self] sheepID in
            guard let self = self, let sheepID = sheepID else {
                print("VoteManager: No sheep playing or screensaver not running")
                return
            }

            // Submit vote to server
            self.submitVote(sheepID: sheepID, direction: direction) { success in
                if success {
                    // Send feedback to screensaver
                    NotificationBridge.shared.sendVoteFeedback(direction: direction)
                    print("VoteManager: Vote submitted successfully for \(sheepID)")
                } else {
                    // Queue for later
                    self.queueOfflineVote(sheepID: sheepID, direction: direction)
                    print("VoteManager: Vote queued for later")
                }
            }
        }
    }

    // MARK: - Server Communication

    private func submitVote(sheepID: String, direction: VoteDirection, completion: @escaping (Bool) -> Void) {
        let uuid = getUUID()
        let vote = direction == .up ? 1 : -1

        // Server uses GET request: /cgi/vote.cgi?id={id}&vote={vote}&u={uuid}
        var components = URLComponents(string: voteBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "id", value: sheepID),
            URLQueryItem(name: "vote", value: String(vote)),
            URLQueryItem(name: "u", value: uuid)
        ]

        guard let url = components.url else {
            completion(false)
            return
        }

        let task = session.dataTask(with: url) { _, response, error in
            if let error = error {
                print("VoteManager: Vote submission failed: \(error.localizedDescription)")
                completion(false)
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }
        task.resume()
    }

    // MARK: - Offline Vote Queue

    private func queueOfflineVote(sheepID: String, direction: VoteDirection) {
        let vote = SheepVote(
            sheepID: sheepID,
            vote: direction == .up ? 1 : -1,
            timestamp: Date(),
            submitted: false
        )

        var votes = loadOfflineVotes()
        votes.append(vote)

        if let data = try? JSONEncoder().encode(votes) {
            try? data.write(to: CacheManager.shared.offlineVotesFile)
        }
    }

    func submitOfflineVotes() {
        var votes = loadOfflineVotes()
        guard !votes.isEmpty else { return }

        for (index, vote) in votes.enumerated() where !vote.submitted {
            let direction: VoteDirection = vote.vote > 0 ? .up : .down
            submitVote(sheepID: vote.sheepID, direction: direction) { success in
                if success {
                    votes[index] = SheepVote(
                        sheepID: vote.sheepID,
                        vote: vote.vote,
                        timestamp: vote.timestamp,
                        submitted: true
                    )
                }
            }
        }

        // Remove submitted votes
        votes = votes.filter { !$0.submitted }

        if let data = try? JSONEncoder().encode(votes) {
            try? data.write(to: CacheManager.shared.offlineVotesFile)
        }
    }

    private func loadOfflineVotes() -> [SheepVote] {
        guard let data = try? Data(contentsOf: CacheManager.shared.offlineVotesFile),
              let votes = try? JSONDecoder().decode([SheepVote].self, from: data) else {
            return []
        }
        return votes
    }

    private func getUUID() -> String {
        UserDefaults.standard.string(forKey: "ElectricSheepUUID") ?? ""
    }
}

// MARK: - Carbon Hotkey Handler

private func hotKeyHandler(nextHandler: EventHandlerCallRef?,
                           event: EventRef?,
                           userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotkeyID = EventHotKeyID()
    GetEventParameter(event,
                      EventParamName(kEventParamDirectObject),
                      EventParamType(typeEventHotKeyID),
                      nil,
                      MemoryLayout<EventHotKeyID>.size,
                      nil,
                      &hotkeyID)

    switch hotkeyID.id {
    case 1: // Vote up
        VoteManager.shared.handleVote(direction: .up)
    case 2: // Vote down
        VoteManager.shared.handleVote(direction: .down)
    default:
        break
    }

    return noErr
}
