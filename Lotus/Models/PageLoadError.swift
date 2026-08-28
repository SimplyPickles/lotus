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
        let displayURL = url?.absoluteString ?? host

        if isHTTPSFailure {
            return (
                "HTTPS Unavailable",
                "Lotus attempted to connect to “\(host)” securely over HTTPS, but the server does not support a secure connection.",
                "lock.slash"
            )
        }

        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return (
                    "Server Unreachable",
                    "Lotus can’t open the page “\(displayURL)” because Lotus cannot find the server “\(host)”. Check the address for typing errors or verify your network connection.",
                    "globe.badge.chevron.backward"
                )
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return (
                    "No Connection",
                    "Lotus can’t open the page “\(displayURL)” because you are not connected to the internet. Please check your network connection and try again.",
                    "wifi.slash"
                )
            case NSURLErrorTimedOut:
                return (
                    "Timed Out",
                    "Lotus can’t open the page “\(displayURL)” because the server where this page is located isn’t responding. The site may be experiencing high traffic or network issues.",
                    "clock.badge.exclamationmark"
                )
            case NSURLErrorCannotConnectToHost, NSURLErrorBadServerResponse:
                return (
                    "Connection Failed",
                    "Lotus can’t connect to the server “\(host)”. The server may be busy or experiencing network difficulties.",
                    "server.rack"
                )
            case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid, NSURLErrorClientCertificateRejected:
                return (
                    "Security Error",
                    "Lotus can’t verify the identity of the website “\(host)”. The certificate for this server is invalid, expired, or untrusted.",
                    "lock.trianglebadge.exclamationmark"
                )
            case NSURLErrorHTTPTooManyRedirects, NSURLErrorRedirectToNonExistentLocation:
                return (
                    "Redirect Loop",
                    "Lotus can’t open the page “\(displayURL)” because too many redirects occurred attempting to open it. Clearing cookies for this site may solve the problem.",
                    "arrow.triangle.2.circlepath"
                )
            default:
                break
            }
        }

        if error.domain == "WebKitErrorDomain" {
            switch error.code {
            case 101: // WebKitErrorCannotShowURL
                return (
                    "Invalid Address",
                    "Lotus can’t open the page “\(displayURL)” because the address is invalid or cannot be displayed.",
                    "safari"
                )
            case 102: // WebKitErrorCannotShowMIMEType
                return (
                    "Unsupported Format",
                    "Lotus can’t display this content because the file format is not supported.",
                    "doc.badge.arrow.up"
                )
            default:
                break
            }
        }

        return (
            "Load Error",
            error.localizedDescription.isEmpty ? "An unexpected network error occurred while attempting to load “\(displayURL)”." : "Lotus can’t open the page “\(displayURL)”. The error was: “\(error.localizedDescription)”",
            "exclamationmark.triangle"
        )
    }
}
