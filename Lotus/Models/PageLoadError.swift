//
//  PageLoadError.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import Foundation

/// Represents a failed navigation or network request error for display in error interstitials.
struct PageLoadError: Identifiable, Equatable {
    let id = UUID()
    let url: URL?
    let code: Int
    let domain: String
    let localizedDescription: String
    let title: String
    let message: String
    let systemImage: String
    let isHTTPSEnforcedFailure: Bool

    init(
        url: URL?,
        error: Error,
        isHTTPSEnforcedFailure: Bool = false
    ) {
        self.url = url
        self.isHTTPSEnforcedFailure = isHTTPSEnforcedFailure
        let nsError = error as NSError
        self.code = nsError.code
        self.domain = nsError.domain
        self.localizedDescription = nsError.localizedDescription

        let (derivedTitle, derivedMessage, derivedIcon) = Self.deriveErrorInfo(for: nsError, url: url, isHTTPSFailure: isHTTPSEnforcedFailure)
        self.title = derivedTitle
        self.message = derivedMessage
        self.systemImage = derivedIcon
    }

    private static func deriveErrorInfo(for error: NSError, url: URL?, isHTTPSFailure: Bool) -> (String, String, String) {
        let host = url?.host ?? "This page"

        if isHTTPSFailure {
            return (
                "HTTPS Connection Unavailable",
                "Lotus attempted to connect to \(host) securely over HTTPS, but the server does not support a secure connection.",
                "lock.slash"
            )
        }

        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return (
                    "Server Not Found",
                    "Lotus cannot find the server at \(host). Check the address for typing errors or verify your DNS settings.",
                    "globe.badge.chevron.backward"
                )
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return (
                    "You Are Offline",
                    "Lotus is unable to connect to the internet. Please check your network connection and try again.",
                    "wifi.slash"
                )
            case NSURLErrorTimedOut:
                return (
                    "Connection Timed Out",
                    "The server at \(host) took too long to respond. The site may be experiencing high traffic or network issues.",
                    "clock.badge.exclamationmark"
                )
            case NSURLErrorCannotConnectToHost, NSURLErrorBadServerResponse:
                return (
                    "Cannot Connect to Server",
                    "Lotus established a connection, but the server at \(host) refused it or returned an invalid response.",
                    "server.rack"
                )
            case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid, NSURLErrorClientCertificateRejected:
                return (
                    "Secure Connection Failed",
                    "Lotus cannot verify the identity of \(host) because its security certificate is invalid, expired, or untrusted.",
                    "lock.trianglebadge.exclamationmark"
                )
            case NSURLErrorHTTPTooManyRedirects, NSURLErrorRedirectToNonExistentLocation:
                return (
                    "Too Many Redirects",
                    "The page at \(host) is redirecting in a way that will never complete. Clearing cookies for this site may help.",
                    "arrow.triangle.2.circlepath.circle"
                )
            default:
                break
            }
        }

        return (
            "Unable to Load Page",
            error.localizedDescription.isEmpty ? "An unexpected network error occurred while attempting to load \(host)." : error.localizedDescription,
            "exclamationmark.triangle"
        )
    }
}
