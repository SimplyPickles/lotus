# Lotus

A native, lightweight macOS web browser built entirely in Swift and SwiftUI on top of WebKit (`WKWebView`).

Lotus combines a vertical-tab sidebar, split-view multitasking, color-coded tab folders, an interactive command palette, adaptive site theming, and native SwiftUI internal pages into a fluid, sandboxed Mac app with zero third-party dependencies.

---

## Highlights

- **Vertical Tabstrip & Floating Sidebar**
  - Tabs live in a collapsible, resizable vertical sidebar.
  - Hovering the left window edge when collapsed smoothly reveals a floating frosted-glass panel.
  - Smooth drag-and-drop reordering with live ghost previews and a multi-column pinned tabs grid.
  - Multi-tab range selection (`⇧`+click) for batch closing, moving, and dragging.

- **Color-Coded Tab Folders**
  - Organize tabs into collapsible folders with custom names and cycling color palettes.
  - Create folders from context menus or by dragging tabs.
  - Moving tabs preserves folder contiguity and state across sessions.

- **Side-by-Side Split View**
  - Open two tabs side-by-side with magnetic resize snapping (50/50, 1/3, 2/3) and custom ratio persistence.
  - Drag a tab toward the window edges to reveal magnetic split-view drop targets.
  - Split pairs stay unified in folders and reorder atomically.

- **Built-in Shields & Privacy Protection**
  - High-performance, declarative WebKit rule blocking for ads, trackers, analytics, push prompts, and cryptominers.
  - **YouTube Ad Stripper & Fast-Forwarder**: Intercepts player payloads, suppresses anti-adblock modals, and skips in-stream video ads.
  - **Anti-Fingerprinting**: Normalizes hardware/screen metrics, prevents battery side-channels, and injects session noise into Canvas, WebGL, WebAudio, and MediaDevices.
  - **Toolbar Shield Popover**: Live toggle for Shields, strict popup blocking, and per-site fingerprint protection with deflection animation pulses.

- **Refined Microinteractions & Motion Design**
  - **Fluid Suggestion Capsule**: Matched-geometry navigation capsule in the command palette.
  - **Ghost URL Auto-Complete**: Smooth lateral drift fading aligned with user typing pace.
  - **Download Catch Ring**: Flying particle animation smoothly docks with a blue spring heartbeat catch ring.
  - **Copy URL Radial Bloom**: Non-intrusive accent bloom in the address bar on copy with automatic internal-page suppression.
  - **Shield Deflection Spark**: Subtly radiates upon blocking web traps, trackers, and ad injections.

- **Command Palette (`⌘T` / `⌘L`)**
  - Fast, distraction-free launcher with a frosted backdrop.
  - Live search suggestions blended with domain heuristics, cached in-memory and debounced.
  - Instant keyboard navigation with `↑`, `↓`, `Tab`, and `Return`.

- **Adaptive Site Theming**
  - Extracts dominant colors from site favicons via CoreImage and tints chrome elements.
  - Automatically calculates contrast luminance for light vs. dark site palettes.
  - Dynamic page-load bloom animations.

- **Native Internal Pages (`lotus://`)**
  - **`lotus://history` (`⌘Y`)**: Searchable, date-grouped browsing history viewer.
  - **`lotus://downloads` (`⌘⌥L`)**: Download manager with live progress, file reveal in Finder, and retry support.
  - **`lotus://settings` (`⌘,`)**: Native preferences, Shields management, and browser customization.

- **Interactive Downloads & Flying Animation**
  - Visual particle animation flying from download links directly into the toolbar download button.
  - Quick-access recent downloads popover with progress bars and cancellation.

- **In-Page Find Bar (`⌘F`)**
  - Floating, non-intrusive find bar with live match counts, match cycling (`⌘G` / `⌘⇧G`), and instant highlight navigation.

- **Picture-in-Picture (Auto-PiP)**
  - Automatically detaches playing HTML5 videos into Picture-in-Picture when switching tabs.

- **Session Persistence & Recovery**
  - Atomically writes session snapshots (tabs, folders, split views, zoom levels, recently closed stack) to Application Support with automatic backup rotation.
  - Full recently-closed tab stack with `⌘⇧T`.

- **Pro macOS Chrome & App Sandbox**
  - Custom traffic-light positioning and window drag regions.
  - App Sandbox enabled with network client/server and user-selected file read access.
  - Quit confirmation dialog with optional "always quit" preference.

---

## Keyboard Shortcuts

Lotus uses a declarative shortcut table (`LotusShortcuts.table`) with conflict assertion and `NSEvent` key monitoring for seamless handling even while web views are focused.

### Window & Sidebar

| Shortcut | Action |
| --- | --- |
| `⌘S` | Toggle sidebar |
| `⌘T` | Open Command Palette (New Tab) |
| `⌘W` | Close active tab |
| `⌘⇧T` | Reopen last closed tab |
| `⌘,` | Open Settings (`lotus://settings`) |
| `⌘Y` | Open History (`lotus://history`) |
| `⌘⌥L` | Open Downloads (`lotus://downloads`) |
| `⌘Q` | Quit (with confirmation modal) |

### Navigation & Search

| Shortcut | Action |
| --- | --- |
| `⌘L` | Focus address bar / Command Palette for current tab |
| `⌘R` | Reload page |
| `⌘[` / `⌘←` | Navigate back |
| `⌘]` / `⌘→` | Navigate forward |
| `⌘⇧C` | Copy current page URL |
| `⌘F` | Find in page |
| `⌘G` | Find next match |
| `⌘⇧G` | Find previous match |
| `⌘P` | Print page |

### Tab Switching

| Shortcut | Action |
| --- | --- |
| `⌘1` … `⌘8` | Jump to tab *n* |
| `⌘9` | Jump to last tab |
| `Ctrl+Tab` / `⌘Tab` | Next tab |
| `Ctrl+⇧Tab` / `⌘⇧Tab` | Previous tab |
| `⌘⌥→` / `⌘⇧]` | Next tab |
| `⌘⌥←` / `⌘⇧[` | Previous tab |

### Zoom

| Shortcut | Action |
| --- | --- |
| `⌘+` / `⌘=` | Zoom in |
| `⌘-` | Zoom out |
| `⌘0` | Reset zoom to 100% |

---

## Requirements

- **macOS 27.0** or later (Apple Silicon or Intel)
- **Xcode 16+** with matching macOS SDK
- Swift 5 toolchain

---

## Building & Running

1. Clone the repository:
   ```sh
   git clone https://github.com/dylanfraser/Lotus.git
   cd Lotus
   ```

2. Build from the command line:
   ```sh
   # Debug build (ad-hoc signing)
   xcodebuild -project Lotus.xcodeproj -scheme Lotus -configuration Debug -destination 'platform=macOS' build
   ```

3. Or open in Xcode:
   ```sh
   open Lotus.xcodeproj
   ```
   Select the **Lotus** scheme and press `⌘R` to run.

---

## Architecture & Codebase Map

State flows unidirectionally through a single observable controller: **`BrowserState`**. Views remain thin and never own browser business logic.

```
Lotus/
├── App/
│   ├── LotusApp.swift                # @main app entry & system menu commands
│   ├── AppDelegate.swift             # App lifecycle & quit interception
│   ├── ContentView.swift             # Root layout, floating sidebar & split overlay
│   └── KeyboardShortcuts.swift       # Declarative shortcut table & NSEvent monitor
│
├── Models/
│   ├── TabItem.swift                 # Tab value struct (title, URL, pinned, folderId)
│   ├── TabFolder.swift               # Folder value struct (name, color, collapsed)
│   ├── SidebarTabUnit.swift          # Atomic sidebar items (single tab or split pair)
│   ├── BrowserSessionData.swift      # Serializable session snapshot (Codable)
│   ├── ContentBlockerConfig.swift    # Shields settings & domain allowlists
│   ├── ClosedTabRecord.swift         # Closed tab history record for restore
│   ├── HistoryItem.swift             # History entry model
│   └── DownloadItem.swift            # Download progress and state model
│
├── ViewModels/
│   ├── BrowserState.swift            # Published properties & core controller
│   ├── BrowserState+Tabs.swift       # Tab CRUD, selection, pinning, reopening
│   ├── BrowserState+Folders.swift    # Folder creation, rename, close, move contiguity
│   ├── BrowserState+TabReordering.swift # Drag-and-drop atomic unit moving
│   ├── BrowserState+TabSelection.swift  # Range and multi-tab sidebar selection
│   ├── BrowserState+WebViews.swift   # WKWebView store, lifecycle & KVO observers
│   ├── BrowserState+Navigation.swift # Navigation delegate & action handlers
│   ├── BrowserState+UIDelegate.swift # JavaScript dialogs & window creation
│   ├── BrowserState+ContentBlocker.swift # Shields & per-site protection facades
│   ├── BrowserState+Clipboard.swift  # URL copying & toast feedback
│   ├── BrowserState+Downloads.swift  # WebKit download delegate & flying animations
│   ├── BrowserState+History.swift    # Browsing history visit recording
│   ├── BrowserState+Find.swift       # In-page text search
│   ├── BrowserState+Theming.swift    # Theme color extraction & light/dark contrast
│   ├── BrowserState+PictureInPicture.swift # Automatic background video PiP
│   ├── BrowserState+SessionPersistence.swift # Save/restore coordination
│   └── BrowserState+Quit.swift       # Modal quit confirmation flow
│
├── Services/
│   ├── ContentBlockerService.swift   # Shields engine & rule manager singleton
│   ├── ContentBlockerRules.swift     # JSON compilation for ad/tracker/fingerprint rules
│   ├── WebViewFactory.swift          # WKWebViewConfiguration & WKProcessPool singleton
│   ├── UserScripts.swift             # Injected user scripts (Shields, noise, media)
│   ├── SessionStore.swift            # File-based JSON persistence in Application Support
│   ├── HistoryStore.swift            # History file persistence with entry pruning
│   ├── DownloadStore.swift           # Download history store
│   ├── FaviconColorExtractor.swift   # CoreImage color clustering & palette extraction
│   ├── ColorParser.swift             # Color space conversion & hex utilities
│   ├── SearchSuggestionService.swift # Autocomplete & domain heuristic engine
│   └── URLInputResolver.swift        # URL vs. search query disambiguation
│
├── Views/
│   ├── Browser/                      # Container, toolbar, Shields popover, webview host
│   ├── Tabstrip/                     # Vertical sidebar, buttons, folder rows, drag & drop
│   ├── CommandPalette/               # ⌘T command palette with live suggestions
│   └── Internal/                     # Native lotus:// history, downloads, settings pages
│
├── Components/                       # VisualEffectView, WindowDragArea, TrafficLights
└── Extensions/                       # URL+Lotus (scheme checks), NSResponder helpers
```

---

## License

All rights reserved.
