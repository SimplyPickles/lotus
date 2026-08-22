# Lotus Roadmap

A living list of suggested fixes, improvements, and features. Ordered roughly by priority within each section. Check items off as they land.

---

## 🐛 Fixes & Correctness

- [ ] **Session restore doesn't reload web content.** Restored tabs show their saved title/URL but the `WKWebView`s are blank until the user interacts. On init, lazily load each restored tab's URL (or at least the selected tab) from its persisted URL.
- [ ] **Session persistence writes on every mutation.** `BrowserState` saves via `didSet` on every published change (including progress updates and hover state churn). Debounce saves or move to explicit save points (tab open/close, navigation commit, termination) to reduce disk I/O.
- [ ] **UserDefaults is fragile for session data.** A corrupted blob silently falls back to sample tabs with no recovery path. Consider a file-based store in Application Support with versioned Codable, plus a backup of the last good session.
- [ ] **`navigateActiveTab` sets the tab title to the hostname immediately**, so the title is wrong until page load finishes updating it. Let the webview's `title` observer drive it instead of pre-setting.
- [ ] **Search fallback hardcodes Google.** Extract to a configurable `searchEngineURL(for:)` — groundwork for a search-engine setting.
- [ ] **`removeTab` on the last tab**: verify behavior when all tabs are closed (currently guarded by `saveSession`'s `!tabs.isEmpty`, but the UI path should be audited — closing the final tab should either quit, show `lotus://newtab`, or be prevented explicitly).
- [ ] **Key monitor swallows Cmd←/Cmd→ even when the webview can't navigate further back/forward is handled, but text-editing contexts inside the web content itself aren't covered by `isAnyTextInputFocused`.** Audit focus detection for edge cases (iframe inputs, contenteditable).
- [ ] **Favicon service dependency.** `TabItem.faviconURL` uses Google's `s2/favicons` proxy — a privacy leak (every host visited is sent to Google) and a single point of failure. Prefer fetching `/favicon.ico` from the site directly, falling back to the proxy.
- [ ] **Error pages.** `didFailProvisionalNavigation` currently just resets loading state; render an inline error view (`lotus://error?...`) instead of leaving a blank webview.

## 🧹 Refactors & Code Health

- [ ] **Split up `BrowserState.swift` (917 lines).** Natural seams: navigation delegate → `BrowserState+Navigation.swift`; UIDelegate/JS panels → `+UIDelegate.swift`; session persistence → `+SessionPersistence.swift`; theming → `+Theming.swift`.
- [ ] **Centralize keyboard shortcuts.** They're spread across `ContentView.shortcutHandlers`, `BrowserContainer`, and the `NSEvent` monitor. Consolidate into one declarative table so conflicts are visible.
- [ ] **Replace `webViewStore: [UUID: WKWebView]` dictionary access patterns** with a small `WebViewModel` wrapper that owns observers + theme color per tab, so teardown is guaranteed symmetric with creation.
- [ ] **Observer cleanup audit.** KVO observations are stored per-tab; confirm `removeTab` tears down all of them (including script message handlers registered on the `WKUserContentController`) to avoid leaks on long sessions.
- [ ] **Remove `TabItem.samples`** from production paths — new users should get a single `lotus://newtab`, not Apple/Lotus demo tabs.
- [ ] **String-typed internal URLs.** Introduce a `LotusPage` enum (`case newTab`) with a `url` property instead of scattering `"lotus://newtab"` literals and scheme-string checks.

## ✨ Features

### Near term
- [ ] **Find in page** (Cmd-F) using `WKWebView.find(_:)/find(_:withConfiguration:)`.
- [ ] **Per-tab reload / stop button state** and Cmd-R / Shift-Cmd-R (hard reload ignoring cache).
- [ ] **Full history** — back/forward list UI (long-press on nav buttons), plus a browsable history page (`lotus://history`).
- [ ] **Downloads UI** — observe `WKDownloadDelegate` (macOS 11+) for download progress and a popover/dock badge.
- [ ] **Zoom controls** — Cmd +/-/0 with per-host zoom level persistence.
- [ ] **Print / Export as PDF** (Cmd-P) via `WKWebView.takeSnapshot` or `createPDF`.

### Medium term
- [ ] **Tab management depth**: duplicate tab, mute tab (`WKWebpagePreferences.allowsContentJavaScript`-adjacent media control), drag tabs between windows, "reopen all closed tabs".
- [ ] **Tab groups / folders** in the sidebar, with color labels and collapse.
- [ ] **Bookmarks** — star button in the URL bar, bookmarks bar, `lotus://bookmarks` manager. Persist alongside session data.
- [ ] **Configurable search engine** setting (Google/DuckDuckGo/Bing/custom) feeding `navigateActiveTab` and `SearchSuggestionService`.
- [ ] **Settings window** (`lotus://settings` or native `SettingsScreen`) covering homepage, sidebar defaults, theme tinting on/off, clear-browsing-data.
- [ ] **Private browsing windows/tabs** that skip session persistence and history.
- [ ] **Reader mode** as another internal page, fed by extracted article content.

### Longer term
- [ ] **Extensions story** — even minimal (content-blocker style rules via `WKContentRuleListStore`).
- [ ] **Sync** — bookmarks/history/tab sync across Macs (iCloud or custom).
- [ ] **Multiple windows** with independent `BrowserState` instances (currently a single shared controller).
- [ ] **Per-site permissions UI** (camera/mic/location prompts already partially flow through UIDelegate — surface persistent grants).

## 🔒 Security & Privacy

- [ ] **Credential storage review.** `KeychainManager` stores passwords; confirm autofill only triggers on form submission over HTTPS and that `pendingSaveCredential` never persists plaintext anywhere else.
- [ ] **Block mixed-content / insecure-form warnings** in `decidePolicyFor`.
- [ ] **Pop-up blocking preference** — `createWebViewWith` currently always opens popups as tabs; add user control.
- [ ] **Certificate error handling** — `didReceive challenge` should surface server-trust failures to the user rather than defaulting silently where applicable.

## 🛠 Tooling & Process

- [ ] **Add a test target.** Even without UI tests, unit-test `navigateActiveTab` URL parsing, session encode/decode round-trips, and `ColorParser`.
- [ ] **Add SwiftLint/SwiftFormat config** so style is enforced rather than matched by hand.
- [ ] **Clean up legacy tracked artifacts** (`*.o` files committed before `.gitignore` existed) when convenient.
- [ ] **CI build check** (GitHub Actions running the Debug `xcodebuild` command) to catch compile breaks early — requires macOS runners with beta Xcode availability.
