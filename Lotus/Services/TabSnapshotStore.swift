//
//  TabSnapshotStore.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import AppKit
import WebKit

/// Manages high-resolution static page viewport snapshots for suspended/snoozed tabs,
/// enabling instant visual restoration with zero latency.
final class TabSnapshotStore {
    static let shared = TabSnapshotStore()

    private let memoryCache = NSCache<NSUUID, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 150 * 1024 * 1024 // 150 MB

        let baseTemp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        cacheDirectory = baseTemp.appendingPathComponent("LotusTabSnapshots", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func diskFileURL(for tabId: UUID) -> URL {
        cacheDirectory.appendingPathComponent("\(tabId.uuidString).png")
    }

    /// Asynchronously captures a high-resolution viewport snapshot from a live WKWebView.
    func captureSnapshot(for tabId: UUID, webView: WKWebView, completion: ((NSImage?) -> Void)? = nil) {
        guard webView.bounds.width > 0, webView.bounds.height > 0 else {
            completion?(nil)
            return
        }

        // Avoid snapshotting internal lotus:// pages
        guard webView.url?.isLotusPage != true else {
            completion?(nil)
            return
        }

        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let self = self, let image = image else {
                completion?(nil)
                return
            }

            self.store(image: image, for: tabId)
            completion?(image)
        }
    }

    /// Stores a snapshot in memory and writes to the temporary disk cache.
    func store(image: NSImage, for tabId: UUID) {
        memoryCache.setObject(image, forKey: tabId as NSUUID)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return
            }
            let fileURL = self.diskFileURL(for: tabId)
            try? pngData.write(to: fileURL, options: .atomic)
        }
    }

    /// Retrieves the snapshot for a tab if available (0ms retrieval from RAM, fallback to disk).
    func snapshot(for tabId: UUID) -> NSImage? {
        if let cached = memoryCache.object(forKey: tabId as NSUUID) {
            return cached
        }

        let fileURL = diskFileURL(for: tabId)
        if fileManager.fileExists(atPath: fileURL.path),
           let image = NSImage(contentsOf: fileURL) {
            memoryCache.setObject(image, forKey: tabId as NSUUID)
            return image
        }

        return nil
    }

    /// Evicts snapshot from memory and disk for a closed tab.
    func evict(for tabId: UUID) {
        memoryCache.removeObject(forKey: tabId as NSUUID)
        let fileURL = diskFileURL(for: tabId)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Clears all stored snapshots.
    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
