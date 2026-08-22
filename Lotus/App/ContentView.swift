//
//  ContentView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var browserState = BrowserState()
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHoveringFloatingSidebar: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                if browserState.isSidebarVisible || (browserState.isResizingSidebar && !isHoveringFloatingSidebar) {
                    Tabstrip(browserState: browserState)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(1)
                }

                BrowserContainer(browserState: browserState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)
            }

            // Hover trigger zone on the left edge when sidebar is collapsed
            if !browserState.isSidebarVisible && !isHoveringFloatingSidebar && !browserState.isResizingSidebar {
                Color.white.opacity(0.0001)
                    .frame(width: 18)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                isHoveringFloatingSidebar = true
                            }
                        }
                    }
                    .zIndex(5)
            }

            // Floating sidebar overlay when collapsed and hovered
            if !browserState.isSidebarVisible && (isHoveringFloatingSidebar || browserState.isResizingSidebar) {
                floatingSidebar
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(frostedGlassBackground)
        .background(TrafficLightPositioner(
            leading: (isHoveringFloatingSidebar && !browserState.isSidebarVisible) ? 22 : 20,
            top: (isHoveringFloatingSidebar && !browserState.isSidebarVisible) ? 22 : 20,
            isVisible: browserState.isSidebarVisible || isHoveringFloatingSidebar || browserState.isResizingSidebar
        ))
        .background {
            GlobalShortcutHandlers(browserState: browserState)
        }
        .overlay {
            if browserState.isQuitConfirmationPresented {
                QuitConfirmationView(browserState: browserState)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: browserState.isSidebarVisible)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isHoveringFloatingSidebar)
        .onChange(of: browserState.isSidebarVisible) { visible in
            if visible {
                isHoveringFloatingSidebar = false
            }
        }
        .onAppear {
            AppDelegate.sharedBrowserState = browserState
        }
    }

    private var floatingSidebar: some View {
        Tabstrip(browserState: browserState)
            .background(
                ZStack {
                    VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
                    (colorScheme == .dark ? Color.black.opacity(0.35) : Color(nsColor: .windowBackgroundColor).opacity(0.75))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14), radius: 14, x: 2, y: 1)
            .padding(3)
            .contentShape(Rectangle())
            .onHover { hovering in
                if !browserState.isResizingSidebar {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isHoveringFloatingSidebar = hovering
                    }
                }
            }
    }


    private var frostedGlassBackground: some View {
        VisualEffectView(
            material: .underWindowBackground,
            blendingMode: .behindWindow,
            state: .active
        )
        .overlay(colorScheme == .dark ? Color.black.opacity(0.12) : Color.white.opacity(0.05))
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
