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

- **`Lotus/ViewModels/BrowserState.swift`** — the core. An `ObservableObject` that owns all published state (`@Published var tabs`, `selectedTabId`, sidebar visibility/width, navigation/loading/theme state), the per-tab `WKWebView` store (`webViewStore: [UUID: WKWebView]`, shared process pool), and a global `NSEvent` key monitor. Behavior lives in sibling extensions: `+Tabs` (CRUD/selection/pinning/reopen), `+WebViews` (webview lifecycle + KVO observers), `+Navigation` (WKNavigationDelegate + nav actions), `+UIDelegate` (JS panels, script messages, autofill), `+Theming` (page theme-color extraction), `+SessionPersistence` (save/restore via `SessionStore`), and `+Quit` (confirmation flow). Serializable snapshots (`Models/BrowserSessionData.swift`) are saved from `didSet` observers on every mutation.
- **`Lotus/App/`** — `LotusApp.swift` (`@main`, menu commands), `AppDelegate.swift` (termination interception), `ContentView.swift` (window layout, floating-sidebar hover behavior), and `KeyboardShortcuts.swift` (the declarative shortcut table — see Cross-Cutting Behaviors).
- **`Lotus/Services/WebViewFactory.swift` + `UserScripts.swift`** — the single place WKWebViews/configurations are constructed (user agent, delegates, flags) and the audit point for all injected/evaluated JavaScript.
- **`lotus://` URL scheme** — internal pages. `lotus://newtab` renders `Views/Internal/LotusNewTabView.swift` as a SwiftUI overlay while web content is hidden; it is not loaded into a WKWebView. Use `URL.isLotusPage` (`Extensions/URL+Lotus.swift`) rather than raw scheme-string checks.

### Directory Map

| Path                    | Contents                                                                                                                                                                                                                                  |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Lotus/App/`            | App entry (`LotusApp`), `AppDelegate`, root layout (`ContentView`), keyboard shortcut table (`KeyboardShortcuts`)                                                                                                                         |
| `Lotus/Models/`         | Value types: `TabItem`, `BrowserSessionData`, `ClosedTabRecord`                                                                                                                                                                           |
| `Lotus/ViewModels/`     | `BrowserState` core + behavior extensions (`+Tabs`, `+WebViews`, `+Navigation`, `+UIDelegate`, `+Theming`, `+SessionPersistence`, `+Quit`)                                                                                                |
| `Lotus/Services/`       | `WebViewFactory`, `UserScripts` (all injected JS), `SessionStore`, `KeychainManager` (keychain credentials singleton), `AutoFillController`, `FaviconColorExtractor`, `ColorParser`, `SearchSuggestionService`                            |
| `Lotus/Views/Browser/`  | `BrowserContainer` (layout), `BrowserToolbar` (nav buttons + URL bar), `BrowserChromeTheme` (chrome color derivation), `WebTabContainerView` (`NSViewRepresentable` swapping active WKWebViews), progress indicator, toolbar button style |
| `Lotus/Views/Tabstrip/` | `Tabstrip` (layout) + `Tabstrip+DragAndDrop` / `Tabstrip+ResizeHandle` extensions, `TabDragState`, `TabButton`, `PinnedTabButton`, `FloatingDragTab`, `TabDropDelegate`, new-tab button                                                   |
| `Lot                    | us/Views/Internal/`                                                                                                                                                                                                                       | Internal pages (`LotusNewTabView`) |
| `Lotus/Components/`     | Reusable chrome: visual-effect wrappers, window drag area, traffic-light positioning, quit confirmation                                                                                                                                   |
| `Lotus/Extensions/`     | `URL+Lotus` (`isLotusPage`, `lotusNewTab`), `NSResponder+BeepSuppression`                                                                                                                                                                 |

### Cross-Cutting Behaviors

- **Theming**: the dominant color extracted from each site's favicon tints toolbar/chrome (`activeThemeColor`, `isThemeLight`). Internal pages always use system window background.
- **Quit flow**: Cmd-Q routes through `BrowserState.requestQuit()` → optional confirmation sheet → `AppDelegate.forceTerminate()`. Never bypass this with a bare `NSApp.terminate`.
- **Keyboard shortcuts**: registered in the declarative table in `App/KeyboardShortcuts.swift` (`LotusShortcuts.table`), rendered either as invisible `Button`s (`GlobalShortcutHandlers`) or routed through `BrowserState`'s `NSEvent` monitor (`usesEventMonitor: true`, e.g. Cmd←/→). Add new shortcuts to the table so conflicts stay visible in one place; view-local exceptions (⌘L, ⌘Q, sheet keys) are listed in `LotusShortcuts.localExceptions`. Text-field focus guards go through `isAnyTextInputFocused`.
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
