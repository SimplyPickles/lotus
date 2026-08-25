//
//  BrowserState+Downloads.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import WebKit
import AppKit
import CoreServices

// MARK: - Active Download Cache & Speed Tracker

private final class DownloadSpeedTracker {
    private var lastBytes: Int64 = 0
    private var lastTime: Date = Date()
    private var currentSpeed: Double = 0

    func update(bytesReceived: Int64) -> Double {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastTime)
        guard timeDelta >= 0.20 else { return currentSpeed }

        let bytesDelta = bytesReceived - lastBytes
        guard bytesDelta >= 0 else {
            lastBytes = bytesReceived
            lastTime = now
            return currentSpeed
        }

        let instantaneous = Double(bytesDelta) / timeDelta
        currentSpeed = currentSpeed > 0 ? (currentSpeed * 0.65 + instantaneous * 0.35) : instantaneous
        lastBytes = bytesReceived
        lastTime = now
        return currentSpeed
    }
}

private final class ActiveDownloadTracker {
    static let shared = ActiveDownloadTracker()
    private let lock = NSLock()
    private var items = [ObjectIdentifier: DownloadItem]()
    private var downloadsById = [UUID: WKDownload]()
    private var tasksById = [UUID: URLSessionDownloadTask]()
    private var progressObservers = [UUID: NSKeyValueObservation]()
    private var speedTrackers = [UUID: DownloadSpeedTracker]()

    func set(_ item: DownloadItem, for download: WKDownload) {
        lock.lock()
        items[ObjectIdentifier(download)] = item
        downloadsById[item.id] = download
        speedTrackers[item.id] = DownloadSpeedTracker()
        lock.unlock()
    }

    func setTask(_ task: URLSessionDownloadTask, for id: UUID) {
        lock.lock()
        tasksById[id] = task
        speedTrackers[id] = DownloadSpeedTracker()
        lock.unlock()
    }

    func setObserver(_ observer: NSKeyValueObservation, for id: UUID) {
        lock.lock()
        progressObservers[id]?.invalidate()
        progressObservers[id] = observer
        lock.unlock()
    }

    func updateSpeed(for id: UUID, bytes: Int64) -> Double {
        lock.lock()
        let tracker = speedTrackers[id]
        lock.unlock()
        return tracker?.update(bytesReceived: bytes) ?? 0
    }

    func get(for download: WKDownload) -> DownloadItem? {
        lock.lock()
        defer { lock.unlock() }
        return items[ObjectIdentifier(download)]
    }

    @discardableResult
    func remove(for download: WKDownload) -> DownloadItem? {
        lock.lock()
        defer { lock.unlock() }
        let item = items.removeValue(forKey: ObjectIdentifier(download))
        if let id = item?.id {
            downloadsById.removeValue(forKey: id)
            tasksById.removeValue(forKey: id)
            progressObservers.removeValue(forKey: id)?.invalidate()
            speedTrackers.removeValue(forKey: id)
        }
        return item
    }

    func remove(id: UUID) {
        lock.lock()
        let download = downloadsById.removeValue(forKey: id)
        tasksById.removeValue(forKey: id)
        progressObservers.removeValue(forKey: id)?.invalidate()
        speedTrackers.removeValue(forKey: id)
        if let download = download {
            items.removeValue(forKey: ObjectIdentifier(download))
        }
        lock.unlock()
    }

    func pause(id: UUID, completion: @escaping (Data?) -> Void) {
        lock.lock()
        let download = downloadsById.removeValue(forKey: id)
        let task = tasksById.removeValue(forKey: id)
        progressObservers.removeValue(forKey: id)?.invalidate()
        speedTrackers.removeValue(forKey: id)
        if let download = download {
            items.removeValue(forKey: ObjectIdentifier(download))
        }
        lock.unlock()

        if let download = download {
            download.cancel { resumeData in
                completion(resumeData)
            }
        } else if let task = task {
            task.cancel(byProducingResumeData: { resumeData in
                completion(resumeData)
            })
        } else {
            completion(nil)
        }
    }

    func cancel(id: UUID) {
        lock.lock()
        let download = downloadsById.removeValue(forKey: id)
        let task = tasksById.removeValue(forKey: id)
        progressObservers.removeValue(forKey: id)?.invalidate()
        speedTrackers.removeValue(forKey: id)
        if let download = download {
            items.removeValue(forKey: ObjectIdentifier(download))
        }
        lock.unlock()

        download?.cancel()
        task?.cancel()
    }
}

// MARK: - WKDownloadDelegate

extension BrowserState: WKDownloadDelegate {

    public func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let downloadsDir = downloadDirectory

        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        var cleanFilename = suggestedFilename.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanFilename.isEmpty || cleanFilename == "unknown" || cleanFilename == "download" {
            let mime = response.mimeType?.lowercased() ?? ""
            if mime.contains("png") { cleanFilename = "image.png" }
            else if mime.contains("jpeg") || mime.contains("jpg") { cleanFilename = "image.jpg" }
            else if mime.contains("webp") { cleanFilename = "image.webp" }
            else if mime.contains("gif") { cleanFilename = "image.gif" }
            else if mime.contains("svg") { cleanFilename = "image.svg" }
            else if mime.contains("pdf") { cleanFilename = "document.pdf" }
            else { cleanFilename = "download" }
        }

        let destinationURL = Self.uniqueDestinationURL(for: cleanFilename, in: downloadsDir)
        let totalSize = response.expectedContentLength > 0 ? response.expectedContentLength : nil
        let mimeType = response.mimeType

        let originalURL = download.originalRequest?.url ?? response.url ?? destinationURL
        let item = DownloadItem(
            filename: destinationURL.lastPathComponent,
            originalURL: originalURL,
            destinationURL: destinationURL,
            fileSize: totalSize,
            bytesReceived: 0,
            startedAt: Date(),
            state: .downloading,
            mimeType: mimeType
        )

        ActiveDownloadTracker.shared.set(item, for: download)

        let obs = download.progress.observe(\.completedUnitCount) { [weak self] progress, _ in
            guard let self = self else { return }
            let bytes = progress.completedUnitCount
            let total = progress.totalUnitCount > 0 ? progress.totalUnitCount : totalSize
            let speed = ActiveDownloadTracker.shared.updateSpeed(for: item.id, bytes: bytes)

            DispatchQueue.main.async {
                if let idx = self.downloads.firstIndex(where: { $0.id == item.id }),
                   self.downloads[idx].state == .downloading {
                    self.downloads[idx].bytesReceived = bytes
                    if let total = total, total > 0 {
                        self.downloads[idx].fileSize = total
                    }
                    self.downloads[idx].bytesPerSecond = speed
                }
            }
        }
        ActiveDownloadTracker.shared.setObserver(obs, for: item.id)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.downloadStore.upsert(item, in: &self.downloads)
            self.triggerFlyingDownloadAnimation(filename: item.filename, iconName: item.systemIconName)
        }

        completionHandler(destinationURL)
    }

    public func download(
        _ download: WKDownload,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }

    public func download(
        _ download: WKDownload,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Let WebKit and the system trust store validate server certificates.
        completionHandler(.performDefaultHandling, nil)
    }

    public func downloadDidFinish(_ download: WKDownload) {
        let cachedItem = ActiveDownloadTracker.shared.remove(for: download)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let targetId = cachedItem?.id
            let destination = cachedItem?.destinationURL

            if let index = Self.downloadIndex(
                in: self.downloads,
                id: targetId,
                destinationURL: destination
            ) {
                self.downloads[index].state = .completed
                self.downloads[index].completedAt = Date()

                if let attr = try? FileManager.default.attributesOfItem(atPath: self.downloads[index].destinationURL.path),
                   let fileSize = attr[.size] as? Int64, fileSize > 0 {
                    self.downloads[index].fileSize = fileSize
                    self.downloads[index].bytesReceived = fileSize
                } else if let size = self.downloads[index].fileSize {
                    self.downloads[index].bytesReceived = size
                }

                Self.applyDownloadQuarantine(
                    to: self.downloads[index].destinationURL,
                    sourceURL: cachedItem?.originalURL ?? self.downloads[index].originalURL
                )
                self.downloadStore.save(self.downloads)
                HapticFeedback.perform(.generic, performanceTime: .now)

                self.applyAITidyDownloadNameIfNeeded(downloadId: self.downloads[index].id)
            } else if var item = cachedItem {
                item.state = .completed
                item.completedAt = Date()
                if let attr = try? FileManager.default.attributesOfItem(atPath: item.destinationURL.path),
                   let fileSize = attr[.size] as? Int64, fileSize > 0 {
                    item.fileSize = fileSize
                    item.bytesReceived = fileSize
                }
                Self.applyDownloadQuarantine(to: item.destinationURL, sourceURL: item.originalURL)
                self.downloadStore.upsert(item, in: &self.downloads)
                HapticFeedback.perform(.generic, performanceTime: .now)

                self.applyAITidyDownloadNameIfNeeded(downloadId: item.id)
            }
        }
    }

    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let cachedItem = ActiveDownloadTracker.shared.remove(for: download)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let targetId = cachedItem?.id
            let destination = cachedItem?.destinationURL

            if let index = Self.downloadIndex(
                in: self.downloads,
                id: targetId,
                destinationURL: destination
            ) {
                self.downloads[index].state = .failed
                self.downloads[index].errorMessage = error.localizedDescription
                self.downloads[index].completedAt = Date()
                self.downloads[index].resumeData = resumeData
                self.downloads[index].bytesPerSecond = nil
                self.downloadStore.save(self.downloads)
            }
        }
    }

    private func applyAITidyDownloadNameIfNeeded(downloadId: UUID) {
        let tidyObject = UserDefaults.standard.object(forKey: "lotus.browser.tidyDownloadsEnabled")
        let tidyEnabled = (tidyObject as? Bool) ?? true
        guard tidyEnabled else { return }

        guard let item = downloads.first(where: { $0.id == downloadId }),
              item.state == .completed else { return }

        let originalDestination = item.destinationURL
        guard FileManager.default.fileExists(atPath: originalDestination.path) else { return }

        Task {
            guard let aiSuggestedStem = await FolderNameGenerator.suggestedDownloadName(for: item.filename) else {
                return
            }
            let ext = originalDestination.pathExtension
            let newCleanName = ext.isEmpty ? aiSuggestedStem : "\(aiSuggestedStem).\(ext)"

            await MainActor.run {
                guard let idx = self.downloads.firstIndex(where: { $0.id == downloadId }),
                      self.downloads[idx].state == .completed else { return }

                let currentURL = self.downloads[idx].destinationURL
                let parentDir = currentURL.deletingLastPathComponent()
                let targetURL = Self.uniqueDestinationURL(for: newCleanName, in: parentDir)

                if currentURL != targetURL && FileManager.default.fileExists(atPath: currentURL.path) {
                    do {
                        try FileManager.default.moveItem(at: currentURL, to: targetURL)
                        Self.applyDownloadQuarantine(to: targetURL, sourceURL: self.downloads[idx].originalURL)
                        self.downloads[idx].destinationURL = targetURL
                        self.downloads[idx].filename = targetURL.lastPathComponent
                        self.downloadStore.save(self.downloads)
                    } catch {}
                }
            }
        }
    }

    // MARK: - Unique Destination Calculation

    static func sanitizeFilename(_ name: String) -> String {
        let basename = (name as NSString).lastPathComponent
        var sanitized = basename
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if sanitized.isEmpty {
            return "download"
        }
        if sanitized.hasPrefix(".") {
            sanitized = "download_\(sanitized.dropFirst())"
        }
        
        let tidyObject = UserDefaults.standard.object(forKey: "lotus.browser.tidyDownloadsEnabled")
        let tidyEnabled = (tidyObject as? Bool) ?? true
        if tidyEnabled {
            sanitized = tidyFilename(sanitized)
        }
        
        return sanitized
    }

    /// Cleans and formats downloaded filenames into clean, readable titles (e.g. replaces underscores/dashes with spaces, strips URL noise, hashes, and UUIDs).
    static func tidyFilename(_ filename: String) -> String {
        let ns = filename as NSString
        let ext = ns.pathExtension
        var stem = ns.deletingPathExtension

        // 1. URL-decode if needed
        if let unescaped = stem.removingPercentEncoding {
            stem = unescaped
        }

        // 2. Strip leading/trailing query parameters or fragments if accidentally present in filename
        if let qIdx = stem.firstIndex(of: "?") {
            stem = String(stem[..<qIdx])
        }
        if let fIdx = stem.firstIndex(of: "#") {
            stem = String(stem[..<fIdx])
        }

        // 3. Strip standard UUID patterns (e.g. 550e8400-e29b-41d4-a716-446655440000)
        stem = stem.replacingOccurrences(
            of: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#,
            with: "",
            options: .regularExpression
        )

        // 4. Strip long random hex/alphanumeric checksum hashes (e.g. _a1b2c3d4e5f6, -6473829104, etc.)
        stem = stem.replacingOccurrences(
            of: #"[_-][0-9a-fA-F]{10,}"#,
            with: "",
            options: .regularExpression
        )
        stem = stem.replacingOccurrences(
            of: #"^[0-9a-fA-F]{16,}[_-]"#,
            with: "",
            options: .regularExpression
        )

        // 5. Replace separators (underscores, pluses, multiple hyphens/dots) with spaces
        stem = stem.replacingOccurrences(of: "_", with: " ")
        stem = stem.replacingOccurrences(of: "+", with: " ")
        stem = stem.replacingOccurrences(of: "%20", with: " ")
        stem = stem.replacingOccurrences(of: "-", with: " ")
        
        // 6. Collapse consecutive spaces and trim edge punctuation
        stem = stem.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_.~ "))

        // 7. Capitalize first letter of words if all lowercase
        if !stem.isEmpty && stem == stem.lowercased() {
            stem = stem.capitalized
        }

        if stem.isEmpty {
            stem = "Download"
        }

        return ext.isEmpty ? stem : "\(stem).\(ext)"
    }

    static func uniqueDestinationURL(for filename: String, in directory: URL) -> URL {
        let fileManager = FileManager.default
        let safeName = sanitizeFilename(filename)
        var destination = directory.appendingPathComponent(safeName)

        guard fileManager.fileExists(atPath: destination.path) else {
            return destination
        }

        let nameWithoutExt = destination.deletingPathExtension().lastPathComponent
        let ext = destination.pathExtension

        var counter = 1
        while fileManager.fileExists(atPath: destination.path) {
            let newName = ext.isEmpty
                ? "\(nameWithoutExt) (\(counter))"
                : "\(nameWithoutExt) (\(counter)).\(ext)"
            destination = directory.appendingPathComponent(newName)
            counter += 1
        }

        return destination
    }

    /// Finds only the record associated with a specific Lotus-owned transfer.
    /// A completion callback must never use another in-progress record as a fallback.
    private static func downloadIndex(
        in downloads: [DownloadItem],
        id: UUID?,
        destinationURL: URL?
    ) -> Int? {
        if let id, let index = downloads.firstIndex(where: { $0.id == id }) {
            return index
        }
        if let destinationURL,
           let index = downloads.firstIndex(where: { $0.destinationURL == destinationURL }) {
            return index
        }
        return nil
    }

    /// Marks files written by Lotus as web downloads so Finder and Gatekeeper
    /// retain the usual warning path when a user opens them.
    private static func applyDownloadQuarantine(to fileURL: URL, sourceURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        var resourceURL = fileURL
        var values = URLResourceValues()
        values.quarantineProperties = [
            kLSQuarantineAgentNameKey as String: "Lotus",
            kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload as String,
            kLSQuarantineDataURLKey as String: sourceURL
        ]

        do {
            try resourceURL.setResourceValues(values)
        } catch {
            NSLog("[Lotus] Failed to quarantine download at \(fileURL.path): \(error.localizedDescription)")
        }
    }
}

// MARK: - Downloads Management Actions

extension BrowserState {

    private static let downloadLocationBookmarkKey = "lotus.browser.downloadLocationBookmark"

    static var defaultDownloadDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    }

    var downloadDirectory: URL {
        customDownloadDirectory ?? Self.defaultDownloadDirectory
    }

    func chooseDownloadLocation() {
        let panel = NSOpenPanel()
        panel.title = "Choose Download Location"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = downloadDirectory

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.setDownloadLocation(url)
        }
    }

    func restoreDownloadLocation() {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.downloadLocationBookmarkKey) else { return }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        if url.startAccessingSecurityScopedResource() {
            customDownloadDirectory = url
            if isStale {
                saveDownloadLocationBookmark(for: url)
            }
        }
    }

    private func setDownloadLocation(_ url: URL) {
        let resolvedURL = url.resolvingSymlinksInPath()
        guard resolvedURL.startAccessingSecurityScopedResource() else { return }

        customDownloadDirectory?.stopAccessingSecurityScopedResource()
        customDownloadDirectory = resolvedURL
        saveDownloadLocationBookmark(for: resolvedURL)

    }

    private func saveDownloadLocationBookmark(for url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(bookmark, forKey: Self.downloadLocationBookmarkKey)
    }

    /// Registers a newly initiated WKDownload.
    func handleDownloadInitiated(_ download: WKDownload, from sourceURL: URL?) {
        download.delegate = self
    }

    /// Triggers a download for a given URL directly (supporting http, https, data URLs, and images).
    func downloadURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "data" || scheme == "blob" else {
            return
        }

        let downloadsDir = downloadDirectory
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        // Handle data: image/binary URLs directly
        if url.scheme == "data" {
            let urlString = url.absoluteString
            if let commaIndex = urlString.firstIndex(of: ",") {
                let header = String(urlString[..<commaIndex])
                let dataPart = String(urlString[urlString.index(after: commaIndex)...])

                let ext: String
                if header.contains("image/png") { ext = "png" }
                else if header.contains("image/jpeg") || header.contains("image/jpg") { ext = "jpg" }
                else if header.contains("image/webp") { ext = "webp" }
                else if header.contains("image/gif") { ext = "gif" }
                else if header.contains("image/svg") { ext = "svg" }
                else { ext = "bin" }

                let filename = "image.\(ext)"
                let destinationURL = Self.uniqueDestinationURL(for: filename, in: downloadsDir)

                if let decodedData = Data(base64Encoded: dataPart, options: .ignoreUnknownCharacters) {
                    try? decodedData.write(to: destinationURL)
                    Self.applyDownloadQuarantine(to: destinationURL, sourceURL: url)

                    let item = DownloadItem(
                        filename: filename,
                        originalURL: url,
                        destinationURL: destinationURL,
                        fileSize: Int64(decodedData.count),
                        bytesReceived: Int64(decodedData.count),
                        startedAt: Date(),
                        completedAt: Date(),
                        state: .completed
                    )
                    downloadStore.upsert(item, in: &downloads)
                    triggerFlyingDownloadAnimation(filename: item.filename, iconName: item.systemIconName)
                    HapticFeedback.perform(.generic, performanceTime: .now)
                    return
                }
            }
        }

        let rawFilename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        var cleanFilename = rawFilename
        if !cleanFilename.contains(".") {
            cleanFilename = "\(rawFilename).jpg"
        }
        let destinationURL = Self.uniqueDestinationURL(for: cleanFilename, in: downloadsDir)

        let item = DownloadItem(
            filename: cleanFilename,
            originalURL: url,
            destinationURL: destinationURL,
            startedAt: Date(),
            state: .downloading
        )
        downloadStore.upsert(item, in: &downloads)
        triggerFlyingDownloadAnimation(filename: item.filename, iconName: item.systemIconName)

        var request = URLRequest(url: url)
        request.setValue(WebViewFactory.currentUserAgent, forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.downloadTask(with: request) { [weak self] tempURL, response, error in
            ActiveDownloadTracker.shared.remove(id: item.id)
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    if let index = self.downloads.firstIndex(where: { $0.id == item.id }) {
                        self.downloads[index].state = .failed
                        self.downloads[index].errorMessage = error.localizedDescription
                        self.downloads[index].completedAt = Date()
                        self.downloads[index].bytesPerSecond = nil
                        self.downloadStore.save(self.downloads)
                    }
                    return
                }

                guard let tempURL = tempURL else { return }
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try? FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    Self.applyDownloadQuarantine(to: destinationURL, sourceURL: url)
                    if let index = self.downloads.firstIndex(where: { $0.id == item.id }) {
                        self.downloads[index].state = .completed
                        self.downloads[index].completedAt = Date()
                        self.downloads[index].bytesPerSecond = nil

                        if let attr = try? FileManager.default.attributesOfItem(atPath: destinationURL.path),
                           let fileSize = attr[.size] as? Int64, fileSize > 0 {
                            self.downloads[index].fileSize = fileSize
                            self.downloads[index].bytesReceived = fileSize
                        } else if let total = response?.expectedContentLength, total > 0 {
                            self.downloads[index].fileSize = total
                            self.downloads[index].bytesReceived = total
                        }

                        self.downloadStore.save(self.downloads)
                        HapticFeedback.perform(.generic, performanceTime: .now)

                        self.applyAITidyDownloadNameIfNeeded(downloadId: item.id)
                    }
                } catch {
                    if let index = self.downloads.firstIndex(where: { $0.id == item.id }) {
                        self.downloads[index].state = .failed
                        self.downloads[index].errorMessage = error.localizedDescription
                        self.downloads[index].completedAt = Date()
                        self.downloads[index].bytesPerSecond = nil
                        self.downloadStore.save(self.downloads)
                    }
                }
            }
        }
        ActiveDownloadTracker.shared.setTask(task, for: item.id)

        let obs = task.progress.observe(\.completedUnitCount) { [weak self] progress, _ in
            guard let self = self else { return }
            let bytes = progress.completedUnitCount
            let total = progress.totalUnitCount > 0 ? progress.totalUnitCount : nil
            let speed = ActiveDownloadTracker.shared.updateSpeed(for: item.id, bytes: bytes)

            DispatchQueue.main.async {
                if let idx = self.downloads.firstIndex(where: { $0.id == item.id }),
                   self.downloads[idx].state == .downloading {
                    self.downloads[idx].bytesReceived = bytes
                    if let total = total, total > 0 {
                        self.downloads[idx].fileSize = total
                    }
                    self.downloads[idx].bytesPerSecond = speed
                }
            }
        }
        ActiveDownloadTracker.shared.setObserver(obs, for: item.id)
        task.resume()
    }

    /// Pauses an active download, saving its resumeData if supported.
    func pauseDownload(id: UUID) {
        ActiveDownloadTracker.shared.pause(id: id) { [weak self] resumeData in
            DispatchQueue.main.async {
                guard let self = self else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                    if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                        self.downloads[index].state = .paused
                        self.downloads[index].resumeData = resumeData
                        self.downloads[index].bytesPerSecond = nil
                        self.downloadStore.save(self.downloads)
                    }
                }
            }
        }
    }

    /// Resumes a paused download using saved resumeData or re-initiates the request.
    func resumeDownload(id: UUID) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        let item = downloads[index]
        guard item.state == .paused || item.state == .failed || item.state == .cancelled else { return }

        if let resumeData = item.resumeData {
            downloads[index].state = .downloading
            downloads[index].errorMessage = nil
            downloads[index].bytesPerSecond = nil
            downloadStore.save(downloads)

            let destinationURL = item.destinationURL
            let task = URLSession.shared.downloadTask(withResumeData: resumeData) { [weak self] tempURL, response, error in
                ActiveDownloadTracker.shared.remove(id: id)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let error = error {
                        if let idx = self.downloads.firstIndex(where: { $0.id == id }) {
                            self.downloads[idx].state = .failed
                            self.downloads[idx].errorMessage = error.localizedDescription
                            self.downloads[idx].bytesPerSecond = nil
                            self.downloadStore.save(self.downloads)
                        }
                        return
                    }

                    guard let tempURL = tempURL else { return }
                    do {
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try? FileManager.default.removeItem(at: destinationURL)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                        Self.applyDownloadQuarantine(to: destinationURL, sourceURL: item.originalURL)
                        if let idx = self.downloads.firstIndex(where: { $0.id == id }) {
                            self.downloads[idx].state = .completed
                            self.downloads[idx].completedAt = Date()
                            self.downloads[idx].bytesPerSecond = nil
                            if let attr = try? FileManager.default.attributesOfItem(atPath: destinationURL.path),
                               let fileSize = attr[.size] as? Int64, fileSize > 0 {
                                self.downloads[idx].fileSize = fileSize
                                self.downloads[idx].bytesReceived = fileSize
                            }
                            self.downloadStore.save(self.downloads)
                            HapticFeedback.perform(.generic, performanceTime: .now)
                            self.applyAITidyDownloadNameIfNeeded(downloadId: id)
                        }
                    } catch {
                        if let idx = self.downloads.firstIndex(where: { $0.id == id }) {
                            self.downloads[idx].state = .failed
                            self.downloads[idx].errorMessage = error.localizedDescription
                            self.downloads[idx].bytesPerSecond = nil
                            self.downloadStore.save(self.downloads)
                        }
                    }
                }
            }

            ActiveDownloadTracker.shared.setTask(task, for: item.id)
            let obs = task.progress.observe(\.completedUnitCount) { [weak self] progress, _ in
                guard let self = self else { return }
                let bytes = progress.completedUnitCount
                let total = progress.totalUnitCount > 0 ? progress.totalUnitCount : item.fileSize
                let speed = ActiveDownloadTracker.shared.updateSpeed(for: item.id, bytes: bytes)

                DispatchQueue.main.async {
                    if let idx = self.downloads.firstIndex(where: { $0.id == item.id }),
                       self.downloads[idx].state == .downloading {
                        self.downloads[idx].bytesReceived = bytes
                        if let total = total, total > 0 {
                            self.downloads[idx].fileSize = total
                        }
                        self.downloads[idx].bytesPerSecond = speed
                    }
                }
            }
            ActiveDownloadTracker.shared.setObserver(obs, for: item.id)
            task.resume()
        } else {
            retryDownload(id: id)
        }
    }

    /// Retries a failed or cancelled download by re-requesting its original URL.
    func retryDownload(id: UUID) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        let item = downloads[index]
        downloads[index].state = .downloading
        downloads[index].errorMessage = nil
        downloads[index].bytesReceived = 0
        downloads[index].bytesPerSecond = nil
        downloads[index].startedAt = Date()
        downloads[index].completedAt = nil
        downloadStore.save(downloads)

        downloadURL(item.originalURL)
    }

    /// Cancels an in-progress download.
    func cancelDownload(id: UUID) {
        ActiveDownloadTracker.shared.cancel(id: id)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            if let index = downloads.firstIndex(where: { $0.id == id }) {
                downloads[index].state = .failed
                downloads[index].errorMessage = "Cancelled"
                downloads[index].completedAt = Date()
                downloadStore.save(downloads)
            }
        }
    }

    /// Removes a specific download from the record.
    func removeDownload(id: UUID) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            downloadStore.removeEntries(ids: [id], from: &downloads)
        }
    }

    /// Removes multiple downloads by ID.
    func removeDownloads(ids: Set<UUID>) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            downloadStore.removeEntries(ids: ids, from: &downloads)
        }
    }

    /// Clears completed and failed downloads from the list (Safari-style clear).
    func clearCompletedDownloads() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            downloadStore.clearCompleted(from: &downloads)
        }
    }

    /// Clears all downloads entirely.
    func clearAllDownloads() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            downloadStore.clearAll(entries: &downloads)
        }
    }

    /// Synchronizes download activity and progress to the macOS Dock icon badge.
    func updateDockProgress() {
        let active = downloads.filter { $0.state == .downloading }
        DispatchQueue.main.async {
            if active.isEmpty {
                NSApp.dockTile.badgeLabel = nil
            } else {
                let totalFraction = active.reduce(0.0) { $0 + $1.progressFraction }
                let avgPercent = Int((totalFraction / Double(active.count)) * 100)
                if active.count == 1 {
                    NSApp.dockTile.badgeLabel = "\(avgPercent)%"
                } else {
                    NSApp.dockTile.badgeLabel = "\(active.count) (\(avgPercent)%)"
                }
            }
        }
    }
}
