//
//  DownloadItem.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import Foundation
import AppKit

/// Lifecycle status for a browser download.
enum DownloadState: String, Codable, Equatable {
    case downloading
    case completed
    case failed
    case cancelled
}

/// A recorded file download with metadata, progress, and local destination state.
struct DownloadItem: Identifiable, Codable, Equatable {
    let id: UUID
    var filename: String
    let originalURL: URL
    var destinationURL: URL
    var fileSize: Int64?
    var bytesReceived: Int64
    let startedAt: Date
    var completedAt: Date?
    var state: DownloadState
    var mimeType: String?
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        filename: String,
        originalURL: URL,
        destinationURL: URL,
        fileSize: Int64? = nil,
        bytesReceived: Int64 = 0,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        state: DownloadState = .downloading,
        mimeType: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.originalURL = originalURL
        self.destinationURL = destinationURL
        self.fileSize = fileSize
        self.bytesReceived = bytesReceived
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.state = state
        self.mimeType = mimeType
        self.errorMessage = errorMessage
    }

    // MARK: - Computed Properties

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter
    }()

    var formattedSize: String {
        if let total = fileSize, total > 0 {
            return Self.byteFormatter.string(fromByteCount: total)
        } else if bytesReceived > 0 {
            return Self.byteFormatter.string(fromByteCount: bytesReceived)
        } else {
            return "Zero KB"
        }
    }

    var progressFraction: Double {
        guard let total = fileSize, total > 0 else {
            return state == .completed ? 1.0 : 0.0
        }
        return min(1.0, max(0.0, Double(bytesReceived) / Double(total)))
    }

    var displayHost: String? {
        guard let host = originalURL.host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var fileExtension: String {
        destinationURL.pathExtension.lowercased()
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: destinationURL.path)
    }

    var systemIconName: String {
        switch fileExtension {
        case "dmg", "pkg", "iso":
            return "externaldrive.fill"
        case "zip", "tar", "gz", "tgz", "7z", "rar", "bz2":
            return "archivebox.fill"
        case "png", "jpg", "jpeg", "gif", "webp", "svg", "heic", "tiff":
            return "photo.fill"
        case "mp4", "mov", "mkv", "avi", "webm", "m4v":
            return "film.fill"
        case "mp3", "m4a", "wav", "flac", "aac", "ogg":
            return "music.note"
        case "pdf":
            return "doc.richtext.fill"
        case "swift", "js", "ts", "py", "html", "css", "json", "xml", "c", "cpp", "rs", "go":
            return "chevron.left.forwardslash.chevron.right"
        case "app":
            return "app.fill"
        case "txt", "md", "rtf", "doc", "docx", "pages":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }

    // MARK: - Actions

    func revealInFinder() {
        if fileExists {
            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
        } else {
            let parentDir = destinationURL.deletingLastPathComponent()
            NSWorkspace.shared.open(parentDir)
        }
    }

    func openFile() {
        if fileExists {
            NSWorkspace.shared.open(destinationURL)
        }
    }
}
