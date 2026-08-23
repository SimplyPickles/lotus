//
//  DownloadsFolderMonitor.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation
import AppKit

/// Monitors the user's Downloads directory for newly created or completed files,
/// capturing downloads initiated by WebKit's native context menus (e.g. "Save Image to Downloads",
/// "Save Image As...", "Download Linked File"), drag-and-drop, and external saves.
final class DownloadsFolderMonitor {

    private var sources: [DispatchSourceFileSystemObject] = []
    private let queue = DispatchQueue(label: "lotus.downloads.monitor", qos: .utility)
    private weak var browserState: BrowserState?
    private var knownFilePaths = Set<String>()
    private var isScanning = false

    init(browserState: BrowserState) {
        self.browserState = browserState
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        let baseDir = browserState?.downloadDirectory ?? BrowserState.defaultDownloadDirectory
        let resolvedDir = baseDir.resolvingSymlinksInPath()

        try? FileManager.default.createDirectory(at: resolvedDir, withIntermediateDirectories: true)

        // Seed initial known files
        let directoriesToMonitor = Array(Set([baseDir.path, resolvedDir.path]))
        for dirPath in directoriesToMonitor {
            let dirURL = URL(fileURLWithPath: dirPath)
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            ) {
                for fileURL in contents {
                    knownFilePaths.insert(fileURL.resolvingSymlinksInPath().path)
                }
            }

            let fd = open(dirPath, O_EVTONLY)
            guard fd >= 0 else { continue }

            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .attrib, .link],
                queue: queue
            )

            src.setEventHandler { [weak self] in
                self?.handleFolderChanged()
            }

            src.setCancelHandler { [fd] in
                close(fd)
            }

            src.resume()
            sources.append(src)
        }
    }

    func stopMonitoring() {
        for src in sources {
            src.cancel()
        }
        sources.removeAll()
    }

    private func handleFolderChanged() {
        // Debounce to allow WebKit / file system to finish writing the full image payload
        queue.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.scanNewFiles()
        }
    }

    private func scanNewFiles() {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let baseDir = browserState?.downloadDirectory ?? BrowserState.defaultDownloadDirectory
        let resolvedDir = baseDir.resolvingSymlinksInPath()

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: resolvedDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }

        var newItems: [DownloadItem] = []
        let now = Date()

        for fileURL in contents {
            let resolvedPath = fileURL.resolvingSymlinksInPath().path
            let ext = fileURL.pathExtension.lowercased()

            // Skip incomplete temporary files
            if ext == "download" || ext == "crdownload" || ext == "tmp" || ext == "part" {
                continue
            }

            guard !knownFilePaths.contains(resolvedPath) else { continue }
            knownFilePaths.insert(resolvedPath)

            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey])
            let fileSize = values?.fileSize.map { Int64($0) }
            let creationDate = values?.creationDate ?? now
            let modDate = values?.contentModificationDate ?? now

            // If the file was created or modified within the last 20 seconds, it's a new download
            if abs(now.timeIntervalSince(modDate)) < 20.0 || abs(now.timeIntervalSince(creationDate)) < 20.0 {
                let filename = fileURL.lastPathComponent
                let item = DownloadItem(
                    filename: filename,
                    originalURL: fileURL,
                    destinationURL: fileURL,
                    fileSize: fileSize,
                    bytesReceived: fileSize ?? 0,
                    startedAt: creationDate,
                    completedAt: modDate,
                    state: .completed
                )
                newItems.append(item)
            }
        }

        if !newItems.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let browserState = self.browserState else { return }
                for item in newItems {
                    let path = item.destinationURL.resolvingSymlinksInPath().path
                    if !browserState.downloads.contains(where: { $0.destinationURL.resolvingSymlinksInPath().path == path }) {
                        browserState.downloadStore.upsert(item, in: &browserState.downloads)
                        browserState.triggerFlyingDownloadAnimation(filename: item.filename, iconName: item.systemIconName)
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    }
                }
            }
        }
    }
}
