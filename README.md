# Lotus 🪷

A native macOS web browser, built entirely in Swift and SwiftUI on top of WebKit.

Lotus is a lightweight, glassy browser with a vertical-tab sidebar, live search suggestions, and a UI that adapts its chrome to the colors of the site you're visiting — all in a single, sandboxed Mac app.

---

## Features

- **Vertical tab sidebar** — tabs live in a collapsible left sidebar instead of a horizontal strip. Collapse it and it reappears as a floating, frosted-glass panel when you hover the window edge.
- **Pinned tabs** — keep your essentials anchored at the top of the sidebar.
- **Drag & drop tabs** — reorder by dragging, including a floating drag preview that follows the cursor.
- **Session persistence** — open tabs, pinned state, selected tab, recently-closed history, and sidebar layout are restored automatically on relaunch.
- **Reopen closed tabs** — full recently-closed stack with `⌘⇧T`.
- **Smart address bar** — one field for URLs and search, with a prettified host/path display while browsing and a hairline loading progress indicator baked into the field itself.
- **Live search suggestions** — suggestions from Google's autocomplete endpoint, blended with heuristic matches against popular domains and TLDs, cached in-memory and debounced for responsiveness.
- **Internal pages** — a native `lotus://newtab` start page rendered in SwiftUI (no web content needed).
- **Adaptive site theming** — Lotus extracts a dominant color from each site's favicon (via CoreImage) and tints the toolbar and container to match, switching foreground contrast automatically for light vs. dark themes.
- **Native vibrancy everywhere** — frosted-glass materials, hidden title bar, and custom traffic-light positioning for a true "pro app" feel.
- **Quit protection** — closing the window prompts a native quit confirmation (with an optional "always quit" preference stored in `UserDefaults`).
- **Sandboxed** — runs inside the macOS App Sandbox with network client/server entitlements.

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `⌘T` | New tab |
| `⌘W` | Close tab |
| `⌘⇧T` | Reopen last closed tab |
| `⌘L` | Focus the address bar |
| `⌘R` | Reload |
| `⌘S` | Toggle sidebar |
| `⌘[` / `⌘]` | Back / Forward |
| `⌘1` … `⌘9` | Jump to tab *n* |
| `Ctrl+Tab` / `⌘Tab` | Next tab |
| `Ctrl+⇧Tab` / `⌘⇧Tab` | Previous tab |
| `⌘⌥←` / `⌘⌥→` | Previous / next tab |
| `⌘Q` | Quit (with confirmation) |

## Requirements

- A Mac running **macOS 27** or later (per the current deployment target)
- **Xcode** with the matching macOS SDK
- Swift 5 toolchain

## Getting Started

1. Clone this repository:
   ```sh
   git clone <your-repo-url>
   cd Lotus
   ```
2. Open the project in Xcode:
   ```sh
   open Lotus.xcodeproj
   ```
3. Select the **Lotus** scheme and press `⌘R` to build and run.

There are no external dependencies — everything is built on system frameworks (SwiftUI, AppKit, WebKit, Combine, CoreImage).

## Project Structure

```
Lotus/
├── ContentView.swift            # App entry point, window chrome, global shortcuts
├── BrowserContainer.swift       # Toolbar strip + address bar
├── BrowserState.swift           # Central observable state machine & navigation delegate
├── TabItem.swift                # Tab model (title, URL, pinned)
├── Components/
│   ├── QuitConfirmationView.swift
│   ├── TrafficLightPositioner.swift
│   ├── VisualEffectView.swift
│   └── WindowDragArea.swift
├── Tabstrip/
│   └── Tabstrip.swift           # Vertical sidebar tab list
├── Views/
│   ├── Browser/
│   │   ├── BrowserToolbarButtonStyle.swift
│   │   ├── HairlineProgressIndicator.swift
│   │   └── WebTabContainerView.swift
│   ├── Internal/
│   │   └── LotusNewTabView.swift        # lotus://newtab start page
│   └── Tabstrip/
│       ├── TabButton.swift
│       ├── PinnedTabButton.swift
│       ├── FloatingDragTab.swift
│       ├── NewTabButton.swift
│       └── TabDropDelegate.swift
└── Utilities/
    ├── FaviconColorExtractor.swift      # Dominant-color extraction for site theming
    ├── SearchSuggestionService.swift    # Autocomplete + domain heuristics
    ├── ColorParser.swift
    ├── KeychainManager.swift
    └── AutoFillController.swift
```

## Architecture Notes

- **`BrowserState`** is the single source of truth: an `ObservableObject` that owns the tab array, selection, navigation state, and session serialization (`Codable` snapshots written on every change). It also acts as the shared `WKNavigationDelegate` / `WKUIDelegate`.
- **Views are thin**: SwiftUI views observe `BrowserState` and dispatch intents back to it; keyboard shortcuts are declared as invisible buttons so they participate in the responder chain naturally.
- **WebKit views are kept alive per tab**, preserving each tab's back/forward history independently while SwiftUI drives only the chrome around them.
- **Theming** flows one way: favicon → dominant color → published theme color → toolbar/container tinting, with light/dark foreground decided from the extracted color's luminance.

## Status

Lotus is in active early development. Some capabilities (e.g., password AutoFill integration) are scaffolded in the utilities layer but not yet surfaced in the UI.

## License

No license has been published yet — all rights reserved by default until one is added.
