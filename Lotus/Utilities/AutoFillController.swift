//
//  AutoFillController.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation
import AuthenticationServices
import WebKit
import AppKit

final class AutoFillController: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AutoFillController()

    private var completionHandler: ((Result<KeychainCredential, Error>) -> Void)?
    private weak var targetWebView: WKWebView?

    private override init() {
        super.init()
    }

    /// Triggers system AutoFill modal for Apple Password Manager credentials via ASAuthorizationController.
    func performAutoFillRequest(for webView: WKWebView, completion: ((Result<KeychainCredential, Error>) -> Void)? = nil) {
        self.targetWebView = webView
        self.completionHandler = completion

        if let host = webView.url?.host {
            let savedCredentials = KeychainManager.shared.fetchCredentials(for: host)
            if let first = savedCredentials.first {
                fillCredentials(in: webView, username: first.username, password: first.password)
            }
        }

        let provider = ASAuthorizationPasswordProvider()
        let request = provider.createRequest()

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    /// Injects a username and password directly into active form elements of the target WKWebView.
    func fillCredentials(in webView: WKWebView, username: String, password: String) {
        let escapedUsername = username.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let escapedPassword = password.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")

        let script = """
        (function() {
            function setNativeValue(element, value) {
                var valueSetter = Object.getOwnPropertyDescriptor(element, 'value');
                var prototype = Object.getPrototypeOf(element);
                var prototypeValueSetter = Object.getOwnPropertyDescriptor(prototype, 'value');
                
                if (prototypeValueSetter && valueSetter !== prototypeValueSetter) {
                    prototypeValueSetter.set.call(element, value);
                } else if (valueSetter && valueSetter.set) {
                    valueSetter.set.call(element, value);
                } else {
                    element.value = value;
                }
                element.dispatchEvent(new Event('input', { bubbles: true }));
                element.dispatchEvent(new Event('change', { bubbles: true }));
            }

            var passwordInputs = document.querySelectorAll('input[type="password"]');
            if (passwordInputs.length === 0) return false;

            var passwordInput = passwordInputs[0];
            var form = passwordInput.form;

            setNativeValue(passwordInput, '\(escapedPassword)');

            var userInput = null;
            if (form) {
                userInput = form.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="login"], input[name*="email"], input[autocomplete="username"]');
            }
            if (!userInput) {
                userInput = document.querySelector('input[type="text"], input[type="email"], input[autocomplete="username"]');
            }

            if (userInput) {
                setNativeValue(userInput, '\(escapedUsername)');
            }

            return true;
        })();
        """

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASPasswordCredential {
            let keychainCred = KeychainCredential(
                server: targetWebView?.url?.host ?? "",
                username: credential.user,
                password: credential.password
            )

            if let webView = targetWebView {
                fillCredentials(in: webView, username: credential.user, password: credential.password)
            }

            completionHandler?(.success(keychainCred))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completionHandler?(.failure(error))
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }
}
