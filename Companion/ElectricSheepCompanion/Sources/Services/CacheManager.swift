import Foundation

/// Manages the sheep cache at ~/Library/Application Support/ElectricSheep/
class CacheManager {
    static let shared = CacheManager()

    private let fileManager = FileManager.default

    /// Root directory for all Electric Sheep data
    var rootDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ElectricSheep")
    }

    /// Directory for free sheep videos
    var freeSheepDirectory: URL {
        rootDirectory.appendingPathComponent("sheep/free")
    }

    /// Directory for gold sheep videos
    var goldSheepDirectory: URL {
        rootDirectory.appendingPathComponent("sheep/gold")
    }

    /// Directory for in-progress downloads
    var downloadsDirectory: URL {
        rootDirectory.appendingPathComponent("downloads")
    }

    /// Directory for sheep metadata
    var metadataDirectory: URL {
        rootDirectory.appendingPathComponent("metadata")
    }

    /// Directory for cached server XML lists
    var listsDirectory: URL {
        rootDirectory.appendingPathComponent("lists")
    }

    /// Playback tracking file (LRU)
    var playbackFile: URL {
        rootDirectory.appendingPathComponent("playback.json")
    }

    /// User preferences file
    var configFile: URL {
        rootDirectory.appendingPathComponent("config.json")
    }

    /// Offline votes queue
    var offlineVotesFile: URL {
        rootDirectory.appendingPathComponent("offline_votes.json")
    }

    private init() {}

    /// Creates the directory structure if it doesn't exist
    func ensureDirectoryStructure() {
        let directories = [
            rootDirectory,
            freeSheepDirectory,
            goldSheepDirectory,
            downloadsDirectory,
            metadataDirectory,
            listsDirectory
        ]

        for dir in directories {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Create empty playback.json if it doesn't exist
        if !fileManager.fileExists(atPath: playbackFile.path) {
            try? "{}".data(using: .utf8)?.write(to: playbackFile)
        }
    }

    /// Number of cached sheep
    var sheepCount: Int {
        let freeCount = (try? fileManager.contentsOfDirectory(atPath: freeSheepDirectory.path))?.count ?? 0
        let goldCount = (try? fileManager.contentsOfDirectory(atPath: goldSheepDirectory.path))?.count ?? 0
        return freeCount + goldCount
    }

    /// Total cache size in bytes
    var cacheSize: Int64 {
        return directorySize(freeSheepDirectory) + directorySize(goldSheepDirectory)
    }

    /// Available disk space in bytes
    var availableDiskSpace: Int64 {
        let values = try? rootDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    /// Whether we have enough disk space to continue downloading
    var hasEnoughDiskSpace: Bool {
        return availableDiskSpace > 1_000_000_000 // 1GB minimum
    }

    /// List all cached sheep IDs
    func listCachedSheepIDs() -> Set<String> {
        var ids = Set<String>()

        if let freeFiles = try? fileManager.contentsOfDirectory(atPath: freeSheepDirectory.path) {
            for file in freeFiles {
                if let id = extractSheepID(from: file) {
                    ids.insert(id)
                }
            }
        }

        if let goldFiles = try? fileManager.contentsOfDirectory(atPath: goldSheepDirectory.path) {
            for file in goldFiles {
                if let id = extractSheepID(from: file) {
                    ids.insert(id)
                }
            }
        }

        return ids
    }

    /// Extract sheep ID from filename (e.g., "248_12345_0_240.avi" -> "248=12345=0=240")
    private func extractSheepID(from filename: String) -> String? {
        let name = (filename as NSString).deletingPathExtension
        // Convert filename format to ID format
        return name.replacingOccurrences(of: "_", with: "=")
    }

    /// Path for a sheep file
    func pathForSheep(_ sheep: SheepInfo) -> URL {
        let filename = "\(sheep.generation)_\(sheep.id)_\(sheep.first)_\(sheep.last).avi"
        if sheep.generation >= 10000 {
            return goldSheepDirectory.appendingPathComponent(filename)
        } else {
            return freeSheepDirectory.appendingPathComponent(filename)
        }
    }

    /// Temporary path for in-progress download
    func tempPathForSheep(_ sheep: SheepInfo) -> URL {
        let filename = "\(sheep.generation)_\(sheep.id)_\(sheep.first)_\(sheep.last).tmp"
        return downloadsDirectory.appendingPathComponent(filename)
    }

    /// Move completed download to final location
    func finalizeDownload(from tempPath: URL, to finalPath: URL) throws {
        // Remove existing file if present
        try? fileManager.removeItem(at: finalPath)
        try fileManager.moveItem(at: tempPath, to: finalPath)

        // Notify that cache was updated
        NotificationCenter.default.post(name: .cacheUpdated, object: nil)
    }

    /// Delete a sheep file
    func deleteSheep(_ sheep: SheepInfo) {
        let path = pathForSheep(sheep)
        try? fileManager.removeItem(at: path)
    }

    /// Evict oldest sheep until cache is under size limit
    func evictIfNeeded(maxSize: Int64) {
        guard cacheSize > maxSize else { return }

        // Load playback timestamps
        let playback = loadPlaybackData()

        // Get all sheep files with their last played times
        var sheepFiles: [(URL, Date)] = []

        for dir in [freeSheepDirectory, goldSheepDirectory] {
            if let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in files {
                    let id = extractSheepID(from: file.lastPathComponent) ?? ""
                    let lastPlayed = playback[id] ?? Date.distantPast
                    sheepFiles.append((file, lastPlayed))
                }
            }
        }

        // Sort by last played (oldest first)
        sheepFiles.sort { $0.1 < $1.1 }

        // Delete until under limit
        var currentSize = cacheSize
        for (file, _) in sheepFiles {
            guard currentSize > maxSize else { break }

            if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
               let fileSize = attrs[.size] as? Int64 {
                try? fileManager.removeItem(at: file)
                currentSize -= fileSize
            }
        }
    }

    /// Load playback timestamps
    func loadPlaybackData() -> [String: Date] {
        guard let data = try? Data(contentsOf: playbackFile),
              let dict = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return dict
    }

    /// Update playback timestamp for a sheep
    func updatePlaybackTime(sheepID: String) {
        var playback = loadPlaybackData()
        playback[sheepID] = Date()

        if let data = try? JSONEncoder().encode(playback) {
            try? data.write(to: playbackFile)
        }
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = attrs.fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    }
}
