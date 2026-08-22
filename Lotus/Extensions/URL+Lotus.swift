//
//  URL+Lotus.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation

extension URL {
    /// True for internal `lotus://` pages (e.g. lotus://newtab), which render
    /// as SwiftUI overlays instead of web content.
    var isLotusPage: Bool {
        scheme == "lotus"
    }

    /// The internal new-tab page.
    static let lotusNewTab = URL(string: "lotus://newtab")!
}
