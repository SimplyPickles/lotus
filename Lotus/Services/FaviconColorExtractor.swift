//
//  FaviconColorExtractor.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import AppKit
import CoreImage
import Combine

final class FaviconColorExtractor: ObservableObject {
    static let shared = FaviconColorExtractor()

    @Published private(set) var colorCache: [URL: Color] = [:]
    @Published private(set) var gradientColorsCache: [URL: [Color]] = [:]
    @Published private(set) var imageCache: [URL: NSImage] = [:]
    @Published private(set) var nsColorCache: [URL: NSColor] = [:]
    private var fetchingURLs: Set<URL> = []

    func color(for url: URL?) -> Color? {
        guard let url = url else { return nil }
        if let cached = colorCache[url] {
            return cached
        }
        fetch(for: url)
        return nil
    }

    func nsColor(for url: URL?) -> NSColor? {
        guard let url = url else { return nil }
        if let cached = nsColorCache[url] {
            return cached
        }
        if let c = color(for: url) {
            let ns = NSColor(c)
            nsColorCache[url] = ns
            return ns
        }
        return nil
    }

    func colors(for url: URL?) -> [Color]? {
        guard let url = url else { return nil }
        if let cached = gradientColorsCache[url] {
            return cached
        }
        fetch(for: url)
        return nil
    }

    func image(for url: URL?) -> NSImage? {
        guard let url = url else { return nil }
        if let cached = imageCache[url] {
            return cached
        }
        fetch(for: url)
        return nil
    }

    func prefetch(for url: URL?) {
        guard let url = url else { return }
        if imageCache[url] == nil {
            fetch(for: url)
        }
    }

    func clearCache() {
        colorCache.removeAll()
        gradientColorsCache.removeAll()
        imageCache.removeAll()
        nsColorCache.removeAll()
        fetchingURLs.removeAll()
    }

    private func fetch(for url: URL) {
        guard !fetchingURLs.contains(url) else { return }
        fetchingURLs.insert(url)

        if url.isFileURL {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let data = try? Data(contentsOf: url),
                      let nsImage = NSImage(data: data) else {
                    DispatchQueue.main.async {
                        self?.fetchingURLs.remove(url)
                    }
                    return
                }
                self?.finishFetch(for: url, image: nsImage)
            }
        } else {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode ?? 0
                let isSuccess = (200...299).contains(statusCode)

                if isSuccess, let data = data, let nsImage = NSImage(data: data) {
                    self?.finishFetch(for: url, image: nsImage)
                    return
                }

                // If direct fetch fails, is blocked (e.g. 403 on Discord), or returns 404, fall back to Google favicon CDN
                if let host = url.host, !host.isEmpty, !url.absoluteString.contains("google.com/s2/favicons") {
                    self?.fetchFallback(host: host, originalURL: url)
                } else {
                    DispatchQueue.main.async {
                        self?.fetchingURLs.remove(url)
                    }
                }
            }.resume()
        }
    }

    private func fetchFallback(host: String, originalURL: URL) {
        guard let fallbackURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") else {
            DispatchQueue.main.async {
                self.fetchingURLs.remove(originalURL)
            }
            return
        }

        var request = URLRequest(url: fallbackURL)
        request.timeoutInterval = 5.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(statusCode), let data = data, let nsImage = NSImage(data: data) {
                self?.finishFetch(for: originalURL, image: nsImage)
            } else {
                DispatchQueue.main.async {
                    self?.fetchingURLs.remove(originalURL)
                }
            }
        }.resume()
    }

    private func finishFetch(for url: URL, image nsImage: NSImage) {
        let extracted = extractColors(from: nsImage)

        DispatchQueue.main.async {
            if let extracted = extracted {
                self.colorCache[url] = extracted.average
                self.gradientColorsCache[url] = extracted.palette
            }
            self.imageCache[url] = nsImage
            self.fetchingURLs.remove(url)
        }
    }

    private func extractColors(from image: NSImage) -> (average: Color, palette: [Color])? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let width = 32
        let height = 32
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        struct SampleCluster {
            var h: Double
            var s: Double
            var b: Double
            var count: Int
            var weight: Double
        }

        var clusters: [SampleCluster] = []
        var totalR = 0.0
        var totalG = 0.0
        var totalB = 0.0
        var totalPixels = 0.0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let aRaw = rawData[offset + 3]
                guard aRaw > 30 else { continue } // Skip transparent pixels

                let alpha = Double(aRaw) / 255.0
                let r = min(1.0, (Double(rawData[offset]) / 255.0) / alpha)
                let g = min(1.0, (Double(rawData[offset + 1]) / 255.0) / alpha)
                let b = min(1.0, (Double(rawData[offset + 2]) / 255.0) / alpha)

                totalR += r * alpha
                totalG += g * alpha
                totalB += b * alpha
                totalPixels += alpha

                let nsColor = NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, al: CGFloat = 0
                nsColor.getHue(&h, saturation: &s, brightness: &br, alpha: &al)

                // Weight saturated and distinct colors higher than washed out or near-black/near-white pixels
                let isNearGray = s < 0.12
                let isNearBoundary = br < 0.08 || br > 0.96
                let weight = (isNearGray || isNearBoundary ? 0.3 : 1.0) * (0.4 + Double(s) * 1.6)

                // Find existing cluster
                var matched = false
                for i in clusters.indices {
                    let hDiff = min(abs(clusters[i].h - Double(h)), 1.0 - abs(clusters[i].h - Double(h)))
                    let sDiff = abs(clusters[i].s - Double(s))
                    let bDiff = abs(clusters[i].b - Double(br))

                    if (isNearGray && clusters[i].s < 0.15 && bDiff < 0.25) ||
                       (!isNearGray && hDiff < 0.08 && sDiff < 0.35 && bDiff < 0.40) {
                        let newCount = clusters[i].count + 1
                        clusters[i].h = (clusters[i].h * Double(clusters[i].count) + Double(h)) / Double(newCount)
                        clusters[i].s = (clusters[i].s * Double(clusters[i].count) + Double(s)) / Double(newCount)
                        clusters[i].b = (clusters[i].b * Double(clusters[i].count) + Double(br)) / Double(newCount)
                        clusters[i].count = newCount
                        clusters[i].weight += weight
                        matched = true
                        break
                    }
                }

                if !matched {
                    clusters.append(SampleCluster(h: Double(h), s: Double(s), b: Double(br), count: 1, weight: weight))
                }
            }
        }

        guard totalPixels > 0 else { return nil }

        // Compute average color (boosted)
        let avgR = totalR / totalPixels
        let avgG = totalG / totalPixels
        let avgB = totalB / totalPixels
        let avgNSColor = NSColor(srgbRed: avgR, green: avgG, blue: avgB, alpha: 1.0)
        var avgH: CGFloat = 0, avgS: CGFloat = 0, avgBr: CGFloat = 0, avgAl: CGFloat = 0
        avgNSColor.getHue(&avgH, saturation: &avgS, brightness: &avgBr, alpha: &avgAl)
        let boostedAvg = Color(nsColor: NSColor(hue: avgH, saturation: min(avgS * 1.25, 1.0), brightness: max(avgBr, 0.70), alpha: 1.0))

        // Sort clusters by weight
        clusters.sort { $0.weight > $1.weight }

        var palette: [Color] = []
        var selectedClusters: [SampleCluster] = []

        for cluster in clusters where cluster.count >= 3 {
            // Check distinctness from already selected clusters
            let isDistinct = selectedClusters.allSatisfy { prev in
                let hDiff = min(abs(prev.h - cluster.h), 1.0 - abs(prev.h - cluster.h))
                let sDiff = abs(prev.s - cluster.s)
                let bDiff = abs(prev.b - cluster.b)
                if prev.s < 0.15 && cluster.s < 0.15 {
                    return bDiff > 0.25
                }
                return hDiff > 0.08 || (sDiff > 0.45 && bDiff > 0.3)
            }

            if isDistinct {
                selectedClusters.append(cluster)
                if selectedClusters.count >= 3 { break }
            }
        }

        // If we found only 1 color or 0, synthesize a secondary companion hue for a rich multi-color gradient
        if selectedClusters.isEmpty {
            palette = [boostedAvg]
        } else if selectedClusters.count == 1 {
            let baseH = selectedClusters[0].h
            let baseS = selectedClusters[0].s
            let baseB = selectedClusters[0].b

            if baseS > 0.15 {
                let primaryColor = Color(nsColor: NSColor(hue: baseH, saturation: min(baseS * 1.25, 1.0), brightness: max(baseB, 0.68), alpha: 1.0))
                let secondaryH = (baseH + 0.09).truncatingRemainder(dividingBy: 1.0)
                let secondaryColor = Color(nsColor: NSColor(hue: secondaryH, saturation: max(min(baseS * 1.15, 1.0), 0.5), brightness: min(max(baseB, 0.68) * 1.06, 1.0), alpha: 1.0))
                palette = [primaryColor, secondaryColor]
            } else {
                let lighterColor = Color(nsColor: NSColor(white: min(max(baseB, 0.6) + 0.25, 0.95), alpha: 1.0))
                let darkerColor = Color(nsColor: NSColor(white: max(baseB * 0.7, 0.35), alpha: 1.0))
                palette = [lighterColor, darkerColor]
            }
        } else {
            // Keep dominant cluster as primary (index 0), followed by secondary and tertiary
            palette = selectedClusters.map { cluster in
                let boostedB = max(cluster.b, 0.68)
                let boostedS = min(cluster.s * 1.25, 1.0)
                return Color(nsColor: NSColor(hue: cluster.h, saturation: boostedS, brightness: boostedB, alpha: 1.0))
            }
        }

        return (average: boostedAvg, palette: palette)
    }
}

struct CachedFaviconView: View {
    let url: URL?
    let defaultSystemName: String
    let fallbackColor: Color
    let size: CGFloat

    @ObservedObject private var colorExtractor = FaviconColorExtractor.shared

    var body: some View {
        ZStack {
            if let url = url, let nsImage = colorExtractor.image(for: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .cornerRadius(3)
            } else {
                Image(systemName: defaultSystemName)
                    .font(.system(size: max(8, size - 2), weight: .medium))
                    .foregroundColor(fallbackColor)
                    .frame(width: size, height: size, alignment: .center)
            }
        }
        .frame(width: size, height: size, alignment: .center)
        .contentTransition(.identity)
    }
}
