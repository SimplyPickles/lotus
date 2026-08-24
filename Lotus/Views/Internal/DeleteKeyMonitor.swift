//
//  DeleteKeyMonitor.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import AppKit
import SwiftUI

struct DeleteKeyMonitor: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> DeleteKeyMonitorView {
        let view = DeleteKeyMonitorView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: DeleteKeyMonitorView, context: Context) {
        nsView.action = action
    }
}

final class DeleteKeyMonitorView: NSView {
    var action: (() -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 51 || event.keyCode == 117 else { return event }
            guard let responder = NSApp.keyWindow?.firstResponder,
                  !(responder is NSTextField),
                  !(responder is NSTextView) else { return event }

            self?.action?()
            return nil
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            removeMonitor()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    deinit {
        removeMonitor()
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
