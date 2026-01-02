import Foundation

/// Represents a sheep (fractal flame animation) from the server
struct SheepInfo: Codable, Equatable, Hashable {
    /// Unique ID within the generation
    let id: String

    /// Generation number (0-9999 = free, 10000+ = gold)
    let generation: Int

    /// First frame number
    let first: Int

    /// Last frame number
    let last: Int

    /// Expected file size in bytes (for validation)
    let fileSize: Int64?

    /// Download URL string from server
    let downloadURLString: String?

    /// Full ID string in format "generation=id=first=last"
    var fullID: String {
        "\(generation)=\(id)=\(first)=\(last)"
    }

    /// Whether this is a gold (high-res) sheep
    var isGold: Bool {
        generation >= 10000
    }

    /// Parsed download URL
    var downloadURL: URL? {
        guard let urlString = downloadURLString else { return nil }
        return URL(string: urlString)
    }

    /// Filename for this sheep
    var filename: String {
        "\(generation)_\(id)_\(first)_\(last).avi"
    }
}

/// Sheep metadata stored locally
struct SheepMetadata: Codable {
    let sheep: SheepInfo
    let downloadedAt: Date
    let rating: Int?
    let playCount: Int
    let lastPlayedAt: Date?
}

/// User's vote on a sheep
struct SheepVote: Codable {
    let sheepID: String
    let vote: Int // 1 = up, -1 = down
    let timestamp: Date
    let submitted: Bool
}
