import Foundation
import Compression

/// Handles sheep list fetching and video downloads using pure Swift URLSession
class DownloadManager: NSObject {
    static let shared = DownloadManager()

    enum State: Equatable {
        case idle
        case downloading(current: Int, total: Int)
        case paused
        case error(String)
    }

    private(set) var state: State = .idle {
        didSet {
            NotificationCenter.default.post(name: .downloadProgressChanged, object: nil)
        }
    }

    private(set) var isPaused = false

    private var session: URLSession!
    private var downloadQueue: [SheepInfo] = []
    private var currentDownloadTask: URLSessionDownloadTask?
    private var retryDelay: TimeInterval = 600 // Start at 10 minutes

    // Server URLs - use HTTP (server has self-signed SSL cert)
    private let redirectURL = URL(string: "http://community.sheepserver.net/query.php?q=redir&u=")!
    private let clientVersion = "OSX_C_1.0.0"

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        // Create session with delegate to handle SSL (sheepserver uses self-signed cert)
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// Start the sync process
    func startSync() {
        guard !isPaused else { return }
        state = .idle
        fetchSheepList()
    }

    /// Pause downloading
    func pause() {
        isPaused = true
        currentDownloadTask?.cancel()
        state = .paused
    }

    /// Resume downloading
    func resume() {
        isPaused = false
        if downloadQueue.isEmpty {
            startSync()
        } else {
            downloadNextSheep()
        }
    }

    // MARK: - Fetch Sheep List

    private func fetchSheepList() {
        // First get the redirect URL to find the active server
        let uuid = getOrCreateUUID()
        let url = redirectURL.appendingPathComponent(uuid)

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.handleError("Failed to get server: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let redirectResponse = String(data: data, encoding: .utf8) else {
                self.handleError("Invalid redirect response")
                return
            }

            // Parse redirect to get actual sheep list URL
            self.fetchSheepListFromServer(redirectResponse)
        }
        task.resume()
    }

    private func fetchSheepListFromServer(_ serverInfo: String) {
        // Parse the redirect response to get the sheep list URL
        // Expected format contains URL to v3d0.sheepserver.net or similar
        guard let listURL = parseSheepListURL(from: serverInfo) else {
            handleError("Could not parse sheep list URL")
            return
        }

        var request = URLRequest(url: listURL)
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.handleError("Failed to fetch sheep list: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                self.handleError("Empty sheep list response")
                return
            }

            // Parse XML sheep list
            self.parseSheepList(data)
        }
        task.resume()
    }

    private func parseSheepListURL(from response: String) -> URL? {
        // The redirect response contains server info
        // Use HTTP (not HTTPS) - server uses self-signed cert
        // Format: http://v3d0.sheepserver.net/cgi/list?v=<version>&u=<uuid>
        let uuid = getOrCreateUUID()
        let urlString = "http://v3d0.sheepserver.net/cgi/list?v=\(clientVersion)&u=\(uuid)"
        return URL(string: urlString)
    }

    private func parseSheepList(_ data: Data) {
        // Decompress gzip if needed
        let xmlData: Data
        if data.starts(with: [0x1f, 0x8b]) {
            // Data is gzip compressed
            guard let decompressed = try? decompressGzip(data) else {
                handleError("Failed to decompress sheep list")
                return
            }
            xmlData = decompressed
        } else {
            xmlData = data
        }

        // Parse XML using Foundation's XMLParser
        let parser = SheepListParser()
        let sheep = parser.parse(data: xmlData)

        // Compare with cached sheep
        let cachedIDs = CacheManager.shared.listCachedSheepIDs()
        let newSheep = sheep.filter { !cachedIDs.contains($0.fullID) }

        if newSheep.isEmpty {
            state = .idle
            resetRetryDelay()
            scheduleNextSync(delay: 3600) // Check again in 1 hour
            return
        }

        // Queue new sheep for download
        downloadQueue = newSheep
        downloadNextSheep()
    }

    // MARK: - Download Sheep

    private func downloadNextSheep() {
        guard !isPaused else {
            state = .paused
            return
        }

        guard !downloadQueue.isEmpty else {
            state = .idle
            NotificationBridge.shared.broadcastCacheUpdated()
            scheduleNextSync(delay: 3600)
            return
        }

        // Check disk space
        guard CacheManager.shared.hasEnoughDiskSpace else {
            state = .error("Low disk space")
            scheduleNextSync(delay: 300) // Retry in 5 minutes
            return
        }

        let sheep = downloadQueue.removeFirst()
        let remaining = downloadQueue.count
        state = .downloading(current: 1, total: remaining + 1)

        downloadSheep(sheep) { [weak self] success in
            guard let self = self else { return }

            if success {
                self.resetRetryDelay()
            }

            // Continue with next sheep
            self.downloadNextSheep()
        }
    }

    private func downloadSheep(_ sheep: SheepInfo, completion: @escaping (Bool) -> Void) {
        guard let url = sheep.downloadURL else {
            completion(false)
            return
        }

        let tempPath = CacheManager.shared.tempPathForSheep(sheep)
        let finalPath = CacheManager.shared.pathForSheep(sheep)

        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else {
                completion(false)
                return
            }

            if let error = error {
                print("Download failed for \(sheep.fullID): \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let tempURL = tempURL else {
                completion(false)
                return
            }

            // Validate file size
            if let expectedSize = sheep.fileSize {
                let attrs = try? FileManager.default.attributesOfItem(atPath: tempURL.path)
                let actualSize = attrs?[.size] as? Int64 ?? 0
                if actualSize != expectedSize {
                    print("Size mismatch for \(sheep.fullID): expected \(expectedSize), got \(actualSize)")
                    completion(false)
                    return
                }
            }

            // Move to final location
            do {
                // First move to our temp location
                try? FileManager.default.removeItem(at: tempPath)
                try FileManager.default.moveItem(at: tempURL, to: tempPath)

                // Then to final location
                try CacheManager.shared.finalizeDownload(from: tempPath, to: finalPath)
                completion(true)
            } catch {
                print("Failed to save \(sheep.fullID): \(error.localizedDescription)")
                completion(false)
            }
        }

        currentDownloadTask = task
        task.resume()
    }

    // MARK: - Helpers

    private func handleError(_ message: String) {
        print("DownloadManager error: \(message)")
        state = .error(message)

        // Exponential backoff
        scheduleNextSync(delay: retryDelay)
        retryDelay = min(retryDelay * 2, 86400) // Max 24 hours
    }

    private func resetRetryDelay() {
        retryDelay = 600
    }

    private func scheduleNextSync(delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startSync()
        }
    }

    private func getOrCreateUUID() -> String {
        let key = "ElectricSheepUUID"
        if let uuid = UserDefaults.standard.string(forKey: key) {
            return uuid
        }
        let uuid = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        UserDefaults.standard.set(uuid, forKey: key)
        return uuid
    }

    private func decompressGzip(_ data: Data) throws -> Data {
        // Gzip has a 10-byte header we need to skip for raw DEFLATE decompression
        guard data.count > 10 else { throw NSError(domain: "Gzip", code: 1) }

        // Skip gzip header (10 bytes minimum)
        var headerSize = 10
        let flags = data[3]

        // Check for optional fields in gzip header
        if flags & 0x04 != 0 { // FEXTRA
            guard data.count > headerSize + 2 else { throw NSError(domain: "Gzip", code: 2) }
            let extraLen = Int(data[headerSize]) + Int(data[headerSize + 1]) << 8
            headerSize += 2 + extraLen
        }
        if flags & 0x08 != 0 { // FNAME - null-terminated string
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT - null-terminated string
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1
        }
        if flags & 0x02 != 0 { // FHCRC
            headerSize += 2
        }

        guard data.count > headerSize + 8 else { throw NSError(domain: "Gzip", code: 3) }

        // Extract deflated data (skip header and 8-byte trailer)
        let deflatedData = data.subdata(in: headerSize..<(data.count - 8))

        // Use Compression framework for DEFLATE decompression
        let bufferSize = 1024 * 1024 // 1MB buffer
        var decompressed = Data()

        try deflatedData.withUnsafeBytes { sourcePtr in
            let sourceBuffer = sourcePtr.bindMemory(to: UInt8.self)
            var destBuffer = [UInt8](repeating: 0, count: bufferSize)

            let decodedSize = compression_decode_buffer(
                &destBuffer,
                bufferSize,
                sourceBuffer.baseAddress!,
                deflatedData.count,
                nil,
                COMPRESSION_ZLIB
            )

            guard decodedSize > 0 else {
                throw NSError(domain: "Gzip", code: 4, userInfo: [NSLocalizedDescriptionKey: "Decompression failed"])
            }

            decompressed = Data(destBuffer.prefix(decodedSize))
        }

        return decompressed
    }
}

// MARK: - URLSessionDelegate for SSL handling

extension DownloadManager: URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Allow self-signed certificates for sheepserver.net
        // This matches the original C++ libcurl behavior (CURLOPT_SSL_VERIFYPEER = false)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let host = challenge.protectionSpace.host
            // Only bypass SSL for known sheep servers
            if host.contains("sheepserver.net") || host.contains("archive.org") {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        // Default handling for other hosts
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - XML Parser for Sheep List

class SheepListParser: NSObject, XMLParserDelegate {
    private var sheep: [SheepInfo] = []
    private var currentElement = ""
    private var currentSheep: SheepInfo?

    func parse(data: Data) -> [SheepInfo] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return sheep
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "sheep" {
            currentSheep = SheepInfo(
                id: attributeDict["id"] ?? "",
                generation: Int(attributeDict["generation"] ?? "0") ?? 0,
                first: Int(attributeDict["first"] ?? "0") ?? 0,
                last: Int(attributeDict["last"] ?? "0") ?? 0,
                fileSize: Int64(attributeDict["size"] ?? "0"),
                downloadURLString: attributeDict["url"]
            )
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "sheep", let sheep = currentSheep {
            self.sheep.append(sheep)
            currentSheep = nil
        }
    }
}
