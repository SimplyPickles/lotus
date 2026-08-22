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
    @Published private(set) var imageCache: [URL: NSImage] = [:]
    private var fetchingURLs: Set<URL> = []
    private var proxyFallbacks: Set<URL> = []

    func color(for url: URL?) -> Color? {
        guard let url = url else { return nil }
        if let cached = colorCache[url] {
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

    private func fetch(for url: URL) {
        guard !fetchingURLs.contains(url) else { return }
        fetchingURLs.insert(url)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let data = try? Data(contentsOf: url),
                  let nsImage = NSImage(data: data) else {
                // Direct fetch failed; fall back to the Google favicon proxy.
                if let proxied = self?.proxyFallbackURL(for: url), self?.tryProxyFallback(for: url) == true {
                    if let data = try? Data(contentsOf: proxied),
                       let nsImage = NSImage(data: data) {
                        self?.finishFetch(for: url, image: nsImage)
                    } else {
                        DispatchQueue.main.async {
                            self?.fetchingURLs.remove(url)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.fetchingURLs.remove(url)
                    }
                }
                return
            }

            self?.finishFetch(for: url, image: nsImage)
        }
    }

    private func finishFetch(for url: URL, image nsImage: NSImage) {
        let extractedColor = extractAverageColor(from: nsImage)

        DispatchQueue.main.async {
            if let extractedColor = extractedColor {
                self.colorCache[url] = extractedColor
            }
            self.imageCache[url] = nsImage
            self.fetchingURLs.remove(url)
        }
    }

    // Only fall back to the proxy for site-direct favicon URLs, and only once per URL.
    private func proxyFallbackURL(for url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.path == "/favicon.ico",
              let host = components.host, !host.isEmpty else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }

    private func tryProxyFallback(for url: URL) -> Bool {
        DispatchQueue.main.sync {
            guard !proxyFallbacks.contains(url) else { return false }
            proxyFallbacks.insert(url)
            return true
        }
    }

    private func extractAverageColor(from image: NSImage) -> Color? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        let a = Double(bitmap[3]) / 255.0

        if a < 0.05 { return nil }

        let nsColor = NSColor(red: r, green: g, blue: b, alpha: a)
        var h: CGFloat = 0, s: CGFloat = 0, bVal: CGFloat = 0, aVal: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &bVal, alpha: &aVal)

        let boostedB = max(bVal, 0.70)
        let boostedColor = Color(nsColor: NSColor(hue: h, saturation: min(s * 1.25, 1.0), brightness: boostedB, alpha: 1.0))

        return boostedColor
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
    }
}
