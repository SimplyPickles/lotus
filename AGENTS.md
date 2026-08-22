# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project Overview

**Lotus** is a native macOS web browser built with SwiftUI + WebKit (`WKWebView`). Single Xcode target (`Lotus`), single scheme (`Lotus`). No third-party dependencies — everything is Foundation/SwiftUI/AppKit/WebKit/Security.

- Swift 5 (`SWIFT_VERSION = 5.0`), macOS deployment target **27.0** — building requires a recent (currently beta) Xcode.
- App Sandbox is enabled (`Lotus/Lotus.entitlements`) with `network.client`, `network.server`, and user-selected read-only file access.
- Despite `SUPPORTED_PLATFORMS` listing iOS/xrOS in the pbxproj, this is a Mac app; macOS-only APIs (AppKit, NSEvent monitors, NSVisualEffectView) are used freely and intentionally.
- The project uses Xcode 16+ synchronized folders (`PBXFileSystemSynchronizedRootGroup`). New `.swift` files created anywhere under `Lotus/` are picked up automatically — do not hand-edit `project.pbxproj` to register files.

## Build & Run

```sh
# Build (Debug)
xcodebuild -project Lotus.xcodeproj -scheme Lotus -configuration Debug -destination 'platform=macOS' build

# Build (Release)
xcodebuild -project Lotus.xcodeproj -scheme Lotus -configuration Release -destination 'platform=macOS' build
```

- There is no test target and no test scheme. Do not invent test invocations; verify changes by compiling and, when possible, by launching the app (`open build/.../Lotus.app` or via Xcode).
- Debug builds sign with the ad-hoc identity (`-`); Release configs use automatic signing with development team `KK4F5DA6LD`. Command-line Debug builds should succeed without signing setup.
- Session data persists in `UserDefaults` under `lotus.browser.session`; if state looks corrupted while testing, reset it with `defaults delete devplaceholder.* lotus.browser.session` (the bundle ID contains a per-project unique value — check the app's actual bundle ID first).

## Architecture

State flows one direction through a single observable controller. Views never own browser logic.

- **`Lotus/BrowserState.swift`** — the core. An `ObservableObject` that owns all tab state (`@Published var tabs`, `selectedTabId`, sidebar visibility/width), the per-tab `WKWebView` store (`webViewStore: [UUID: WKWebView]`, shared process pool), navigation/UIDelegate conformance, favicon-derived theming, quit flow, session persistence, and a global `NSEvent` key monitor. Serializable snapshots are saved as a Codable `BrowserSessionData` blob in `UserDefaults` from `didSet` observers on every mutation.
- **`Lotus/ContentView.swift`** — app entry point (`@main`), `AppDelegate` (termination interception), window layout, floating-sidebar hover behavior, and most keyboard shortcuts.
- **`lotus://` URL scheme** — internal pages. `lotus://newtab` renders `Views/Internal/LotusNewTabView.swift` as a SwiftUI overlay while web content is hidden (`BrowserContainer.isInternalLotusPage`); it is not loaded into a WKWebView.

### Directory Map

| Path                    | Contents                                                                                                                                                                                       |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Lotus/*.swift`         | Root: app entry (`ContentView`), `BrowserState`, `BrowserContainer` (toolbar + URL bar), `TabItem` model                                                                                       |
| `Lotus/Tabstrip/`       | Sidebar tab list (`Tabstrip.swift`)                                                                                                                                                            |
| `Lotus/Views/Tabstrip/` | Tab strip pieces: `TabButton`, `PinnedTabButton`, drag-and-drop (`FloatingDragTab`, `TabDropDelegate`), new-tab button                                                                         |
| `Lotus/Views/Browser/`  | Web content hosting (`WebTabContainerView` — `NSViewRepresentable` swapping active WKWebViews), progress indicator, toolbar button style                                                       |
| `Lotus/Views/Internal/` | Internal pages (`LotusNewTabView`)                                                                                                                                                             |
| `Lotus/Components/`     | Reusable chrome: visual-effect wrappers, window drag area, traffic-light positioning, quit confirmation                                                                                        |
| `Lotus/Utilities/`      | Services: `KeychainManager` (keychain credentials singleton), `AutoFillController`, `FaviconColorExtractor` (favicon fetch + dominant-color theming), `ColorParser`, `SearchSuggestionService` |

### Cross-Cutting Behaviors

- **Theming**: the dominant color extracted from each site's favicon tints toolbar/chrome (`activeThemeColor`, `isThemeLight`). Internal pages always use system window background.
- **Quit flow**: Cmd-Q routes through `BrowserState.requestQuit()` → optional confirmation sheet → `AppDelegate.forceTerminate()`. Never bypass this with a bare `NSApp.terminate`.
- **Keyboard shortcuts**: implemented as invisible `Button`s (`.opacity(0).frame(width: 0, height: 0)`) attached in `ContentView.shortcutHandlers` / `BrowserContainer`, plus an `NSEvent.addLocalMonitorForEvents` handler in `BrowserState` for Cmd←/→ navigation. Add new shortcuts following these patterns so they coexist with text-field focus guards (`isAnyTextInputFocused`).
- **WKWebView lifecycle**: one WKWebView per tab, cached across tab switches and re-parented by `WebTabHostNSView.updateActiveWebView`. Popups go through `createWebViewWith`, which creates a new tab sharing the same process pool.

## Conventions

- Every file starts with the standard header comment block (`//  FileName.swift`, `//  Lotus`, `//  Created by ...`).
- Use `// MARK: -` sections to organize larger files.
- Singletons use `static let shared` with a `private init` (see `KeychainManager`, `FaviconColorExtractor`).
- Classes that hold mutable published state are `final class ... ObservableObject`; models (`TabItem`) are value structs conforming to `Codable` where persisted.
- Animations use explicit springs with tuned `response`/`dampingFraction` values; suppress implicit propagation with `.transaction { $0.animation = nil }` where the existing code does.
- AppKit interop goes through `NSViewRepresentable`; keep SwiftUI views free of direct `NSView` manipulation except inside representables.
- No linter/formatter config exists; match surrounding style exactly (indentation, naming, ordering).

## Repo Hygiene

- A standard macOS/Xcode `.gitignore` covers `.DS_Store`, `*.o`, `xcuserdata/`, and `DerivedData`; don't commit those. Some legacy artifacts (`FaviconColorExtractor.o`, etc.) are still tracked from before it existed — leave them alone unless asked to clean up.
- Keep `project.pbxproj` edits minimal; since schemes/targets rarely change, prefer code-only changes.
