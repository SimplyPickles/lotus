//
//  BrowserState+Downloads.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import WebKit
import AppKit

// MARK: - Active Download Cache

private final class ActiveDownloadTracker {
    static let shared = ActiveDownloadTracker()
    private let lock = NSLock()
    private var items = [ObjectIdentifier: DownloadItem]()
    private var downloadsById = [UUID: WKDownload]()
    private var tasksById = [UUID: URLSessionDownloadTask]()

    func set(_ item: DownloadItem, for download: WKDownload) {
        lock.lock()
        items[ObjectIdentifier(download)] = item
        downloadsById[item.id] = download
        lock.unlock()
    }

    func setTask(_ task: URLSessionDownloadTask, for id: UUID) {
        lock.lock()
        tasksById[id] = task
        lock.unlock()
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
        }
        return item
    }

    func cancel(id: UUID) {
        lock.lock()
        let download = downloadsById.removeValue(forKey: id)
        let task = tasksById.removeValue(forKey: id)
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
            filename: cleanFilename,
            originalURL: originalURL,
            destinationURL: destinationURL,
            fileSize: totalSize,
            bytesReceived: 0,
            startedAt: Date(),
            state: .downloading,
            mimeType: mimeType
        )

        ActiveDownloadTracker.shared.set(item, for: download)

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
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }

    public func downloadDidFinish(_ download: WKDownload) {
        let cachedItem = ActiveDownloadTracker.shared.remove(for: download)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let targetId = cachedItem?.id
            let destination = cachedItem?.destinationURL

            if let index = self.downloads.firstIndex(where: {
                ($0.id == targetId) || ($0.destinationURL == destination) || ($0.state == .downloading)
            }) {
                self.downloads[index].state = .completed
                self.downloads[index].completedAt = Date()

                if let attr = try? FileManager.default.attributesOfItem(atPath: self.downloads[index].destinationURL.path),
                   let fileSize = attr[.size] as? Int64, fileSize > 0 {
                    self.downloads[index].fileSize = fileSize
                    self.downloads[index].bytesReceived = fileSize
                } else if let size = self.downloads[index].fileSize {
                    self.downloads[index].bytesReceived = size
                }

                self.downloadStore.save(self.downloads)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            } else if var item = cachedItem {
                item.state = .completed
                item.completedAt = Date()
                if let attr = try? FileManager.default.attributesOfItem(atPath: item.destinationURL.path),
                   let fileSize = attr[.size] as? Int64, fileSize > 0 {
                    item.fileSize = fileSize
                    item.bytesReceived = fileSize
                }
                self.downloadStore.upsert(item, in: &self.downloads)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
    }

    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let cachedItem = ActiveDownloadTracker.shared.remove(for: download)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let targetId = cachedItem?.id
            let destination = cachedItem?.destinationURL

            if let index = self.downloads.firstIndex(where: {
                ($0.id == targetId) || ($0.destinationURL == destination) || ($0.state == .downloading)
            }) {
                self.downloads[index].state = .failed
                self.downloads[index].errorMessage = error.localizedDescription
                self.downloads[index].completedAt = Date()
                self.downloadStore.save(self.downloads)
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
        return sanitized
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

        downloadsMonitor?.stopMonitoring()
        downloadsMonitor = DownloadsFolderMonitor(browserState: self)
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
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
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
        request.setValue(WebViewFactory.userAgent, forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.downloadTask(with: request) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    if let index = self.downloads.firstIndex(where: { $0.id == item.id }) {
                        self.downloads[index].state = .failed
                        self.downloads[index].errorMessage = error.localizedDescription
                        self.downloads[index].completedAt = Date()
                        self.downloadStore.save(self.downloads)
                    }
                    return
                }

                guard let tempURL = tempURL else { return }
                do {
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    if let index = self.downloads.firstIndex(where: { $0.id == item.id }) {
                        self.downloads[index].state = .completed
                        self.downloads[index].completedAt = Date()

                        if let attr = try? FileManager.default.attributesOfItem(atPath: destinationURL.path),
                           let fileSize = attr[.size] as? Int64, fileSize > 0 {
                            self.downloads[index].fileSize = fileSize
                            self.downloads[index].bytesReceived = fileSize
                        } else if let total = response?.expectedContentLength, total > 0 {
                            self.downloads[index].fileSize = total
                            self.downloads[index].bytesReceived = total
                        }

                        self.downloadStore.save(self.downloads)
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    }
                } catch {
                    if let index = self.downloads.firstIndex(where: { $0.id == item.id }) {
                        self.downloads[index].state = .failed
                        self.downloads[index].errorMessage = error.localizedDescription
                        self.downloads[index].completedAt = Date()
                        self.downloadStore.save(self.downloads)
                    }
                }
            }
        }
        ActiveDownloadTracker.shared.setTask(task, for: item.id)
        task.resume()
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
}
