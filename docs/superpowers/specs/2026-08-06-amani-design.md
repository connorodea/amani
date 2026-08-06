# Amani — Design Spec

**Date:** 2026-08-06 (revised same day: multi-trigger activation — hotkey + modifier-hold +
menu bar — replacing the single-hotkey-only design)
**Status:** Approved for M1 implementation planning
**Repo:** `connorodea/amani` (public, MIT license — https://github.com/connorodea/amani)

## 1. Concept

Amani is a native macOS, FOSS application that replaces Apple Spotlight (Cmd+Space) with a
single command bar that does two jobs at once:

1. **Launcher** — everything Spotlight already does: launch apps, find files, do quick math.
2. **Agent command center** — a unified control plane for every agentic process running on
   the machine (Claude Code sessions, loops, workflows, and — over time — other agent CLIs).
   The framing is "OpenRouter for agents, as a command center": one interface that routes to,
   monitors, and controls many different backends, the way OpenRouter unifies many LLM
   providers behind one API.

Later milestones add natural-language semantic search (embeddings + vector store + a
relational knowledge graph) so results — apps, files, agents, past sessions — can be found by
meaning, not just by name.

## 2. Non-goals (all milestones)

- Not a general-purpose Alfred/Raycast clone with a marketplace of unrelated third-party
  workflows — agent control is the point of differentiation, not a side feature.
- Not tied to Claude Code specifically at the architecture level — the process-discovery and
  connector layers must stay generic even though Claude Code is the first and primary target.
- No telemetry / phone-home. FOSS and privacy-respecting by default, matching the precedent
  set by `MacVoiceInput`.

## 3. Milestone roadmap

Each milestone gets its own spec → plan → implementation cycle. This document specs **M1**
in full; M2–M4 are captured here only as a roadmap so later specs have context.

- **M1 — Foundation** *(this spec)*: Cmd+Space takeover, floating overlay UI, baseline
  launcher (apps, files, calculator).
- **M2 — Agent Command Center**: generic process discovery for agent CLIs, start/stop/attach,
  hybrid log capture, live agent state in the results list.
- **M3 — Semantic Search + Knowledge Graph**: natural-language query layer. Embeddings are
  **pluggable — both local (on-device, e.g. llama.cpp/Ollama or Apple's on-device
  NLEmbedding/CoreML) and cloud (e.g. Voyage/OpenAI) are supported**, user-selectable, with a
  local model as the no-setup default so the app works fully offline out of the box. Paired
  with an open-source local vector store and a relational knowledge graph linking
  agents↔projects↔files↔tasks (may reuse ideas from the existing `graphify` skill).
- **M4 — Ecosystem**: additional provider connectors (Codex, Gemini CLI, Cursor, OpenClaw,
  custom scripts), clipboard history, snippets, plugin system, public FOSS polish (README,
  CONTRIBUTING, project site).

## 4. M1 — Foundation

### 4.1 Architecture

Standard SwiftUI menu-bar-style app, but the primary UI is a borderless floating panel
(`NSPanel`) rather than a menu-bar dropdown — shown/hidden by a global hotkey, matching
Spotlight/Alfred/Raycast UX.

```
Amani.app
├── AppDelegate            — lifecycle, activation trigger registration, panel show/hide
├── OverlayWindow (NSPanel)— borderless, floating, centered, key window on activate
├── SearchView (SwiftUI)   — text field + results list, Spotlight-style
├── OrbView (SceneKit)     — the signature visual: a small rotating 3D orb/globe next to
│                             the search field, Siri-inspired ambient motion, glow shader
├── SearchController       — owns query state, debounces input, fans out to providers
├── Result Providers        (protocol-based, so M2+ providers slot in identically)
│   ├── AppLauncherProvider — enumerates + launches .app bundles via NSWorkspace
│   ├── FileSearchProvider  — shells out to `mdfind` for Spotlight-indexed file search
│   └── CalculatorProvider  — local expression evaluation, no shell-out
├── ActivationManager       — owns every way to summon Amani (protocol-based, so new
│                             trigger types add cleanly — "all of them," not just one)
│   ├── HotkeyTrigger       — global key-combo capture (default Cmd+Space), via an
│   │                         existing open-source Swift hotkey library rather than
│   │                         hand-rolled Carbon/Quartz event-tap code
│   ├── ModifierHoldTrigger — hold a lone modifier key (default: Cmd, 5.0s) with no
│   │                         other key pressed during the hold — a raw global
│   │                         `.flagsChanged` NSEvent monitor, since standalone-modifier
│   │                         gestures aren't covered by combo-hotkey libraries
│   └── MenuBarTrigger      — NSStatusItem in the menu bar; click opens the overlay
├── MenuBarController       — owns the persistent NSStatusItem (icon, click handler,
│                             right-click menu: Preferences/Quit) — always present,
│                             independent of Accessibility permission state
└── SetupAssistant          — first-run flow: Accessibility permission, per-trigger
                              enable/disable + hotkey/duration configuration, guided
                              steps to disable Spotlight's own Cmd+Space binding
```

Every `ActivationTrigger` calls the same `OverlayWindow.toggle()` — the overlay doesn't know
or care which trigger summoned it. This is what makes "all of them" cheap: each trigger is a
small, independent, individually toggleable unit behind one protocol.

```swift
protocol ActivationTrigger {
    var id: String { get }
    var isEnabled: Bool { get set }
    func start(onActivate: @escaping () -> Void)
    func stop()
}
```

Result providers are a protocol (`ResultProvider`) from day one — even though M1 only ships
three of them — so M2's agent providers and M3's semantic provider plug into the exact same
result pipeline without a rearchitecture.

```swift
protocol ResultProvider {
    var id: String { get }
    func results(for query: String) async -> [SearchResult]
}
```

### 4.2 Components

- **ActivationManager**: holds the list of registered `ActivationTrigger`s, starts/stops each
  based on its `isEnabled` state (persisted in `UserDefaults`), and routes every trigger's
  activation callback to the same `OverlayWindow.toggle()`. Adding a future trigger type
  (e.g. a Stream Deck button, a Shortcuts.app action) means writing one new
  `ActivationTrigger` conformance — no changes anywhere else.
- **HotkeyTrigger**: registers a global key-combo (default Cmd+Space) via an existing,
  actively-maintained open-source Swift hotkey library (e.g. `HotKey`). On first launch,
  detects whether macOS Spotlight still owns that binding (best-effort, via reading the
  user's Symbolic HotKeys plist) and — if so — walks the user through disabling it in System
  Settings > Keyboard Shortcuts (Apple provides no API to do this programmatically; it's a
  guided manual step, done once). Combo is user-configurable in Preferences; Cmd+Space is
  just the default.
- **ModifierHoldTrigger**: watches global `.flagsChanged` events for a single configured
  modifier key (default: Cmd) being held alone. Starts a timer on key-down; cancels
  immediately if any other key or modifier is pressed before the threshold (default 5.0s,
  configurable) elapses, or if the modifier is released early; fires the activation callback
  once the threshold is reached while still held alone. This is intentionally a separate,
  simpler event path from `HotkeyTrigger` — combo-hotkey libraries match specific key+modifier
  combinations, not "this modifier alone, held for N seconds," so it needs its own raw
  `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` listener and a small internal
  state machine (idle → holding → fired/cancelled).
- **MenuBarTrigger** + **MenuBarController**: a persistent `NSStatusItem` — present the moment
  the app launches, independent of Accessibility permission (menu bar icons don't need it).
  Left-click toggles the overlay (same path as every other trigger); right-click shows a small
  menu (Preferences, Quit). This is also the reliability fallback: if Accessibility permission
  is denied so `HotkeyTrigger`/`ModifierHoldTrigger` can't function, the menu bar icon still
  works, so Amani is never fully inaccessible.
- **OverlayWindow**: a floating, non-activating-by-default `NSPanel`, always centered on the
  active screen, dismissed on Escape or focus loss.
- **SearchController**: single source of truth for the current query; debounces keystrokes
  (~120ms), asks every registered `ResultProvider` for results concurrently, merges/ranks,
  publishes to `SearchView`.
- **AppLauncherProvider**: builds an in-memory index of installed `.app` bundles (via
  `NSWorkspace` / `LSCopyApplicationURLsForBundleIdentifier`-style enumeration) at launch and
  on a filesystem-change watch of `/Applications` + `~/Applications`; fuzzy-matches by name.
- **FileSearchProvider**: shells out to `mdfind -name` (or an MDQuery) so it rides on the
  existing Spotlight metadata index rather than re-indexing the filesystem itself — cheap to
  build, and the one place M1 deliberately still leans on Spotlight infrastructure even though
  Spotlight's UI is being replaced.
- **CalculatorProvider**: parses simple arithmetic expressions in-process, shown as the first
  result when the query looks numeric.
- **OrbView**: an `SCNView` (SceneKit) wrapped for SwiftUI, rendering a small rotating
  orb/globe next to the search field — the signature visual, Siri-inspired rather than a
  literal port of `three-globe` (that's a Three.js/WebGL library; embedding a web view for
  decoration would cost real launch latency and pull in a whole web stack, contrary to the
  "respond at Spotlight speed" and zero-heavy-dependency principles already in the vision).
  Built from an `SCNSphere` (or a low-poly `SCNGeometry` for a faceted "wireframe globe"
  look) with a rim-light/glow shader modifier, continuously rotating with eased,
  non-constant-speed motion (rhythmic, pendulum-like — not a flat linear spin) for the
  astronomical/moon-like feel. Two states in M1: **idle** (slow ambient rotation, present but
  calm) and **active** (subtle speed-up + glow pulse while the user is typing/a query is in
  flight) — a natural hook for M2 to later reflect real agent activity (busier orb when
  agents are running), but M1 only needs the two states tied to local typing/search activity.
- **SetupAssistant**: run once on first launch; requests Accessibility permission (needed for
  `HotkeyTrigger`/`ModifierHoldTrigger` + eventually for agent process control in M2), hands
  off to the guided Spotlight-disable step, and presents the trigger list so the user can
  toggle each on/off and adjust the hotkey combo / hold duration. Defaults: `HotkeyTrigger`
  and `MenuBarTrigger` on, `ModifierHoldTrigger` on with a 5.0s Cmd hold — all three ship
  enabled out of the box, matching "we should have all of them," but every one is a single
  toggle away from off if a trigger conflicts with something else on the user's system.

### 4.3 Data flow

```
Keystroke → SearchController (debounce) → fan out to all ResultProviders concurrently
   → each provider returns [SearchResult] (or empty within a short per-provider timeout)
   → SearchController merges + ranks by provider-declared priority + simple fuzzy score
   → SearchView re-renders result list
Enter/click on a result → SearchResult.action() invoked (launch app / open file / show calc
   result) → OverlayWindow hides
```

No persistence needed in M1 beyond the app index cache (rebuilt on `/Applications` changes)
— no database, no network calls.

### 4.4 Error handling

- A slow or failing provider (e.g. `mdfind` hanging) must not block the others — each
  provider call has a short timeout (~200ms) and partial results are shown; a provider that
  times out just contributes nothing for that keystroke.
- If Accessibility permission is denied, `HotkeyTrigger` and `ModifierHoldTrigger` can't
  function (both require it), but `MenuBarTrigger` doesn't and keeps working — the app is
  never fully inaccessible — with a persistent nudge to grant permission so the other two
  triggers activate.
- `ModifierHoldTrigger`'s state machine must fail safe: any ambiguous event (another key down,
  the modifier released before threshold, focus lost to a secure-input field) resets to idle
  rather than firing. A false activation from a mistimed hold is worse than an occasional
  missed one.
- If the user never completes the "disable Spotlight's Cmd+Space" step, both may fire —
  Amani should not attempt to suppress system Spotlight itself (no supported API for that);
  the setup assistant just keeps surfacing the one remaining manual step until it detects the
  binding is clear.

### 4.5 Testing

- Unit tests (XCTest, matching `MacVoiceInput`'s existing pattern) for: query debouncing,
  result merging/ranking logic, calculator expression parsing, app-index fuzzy matching.
- `FileSearchProvider` and `AppLauncherProvider` tested against fakes/protocols rather than
  hitting the real filesystem/`mdfind` in unit tests; a small number of integration tests may
  shell out for real in CI on macOS runners.
- `ModifierHoldTrigger`'s state machine is tested in isolation by feeding it synthetic
  flags-changed event sequences (a fake clock, not real 5-second waits) — cover: clean hold to
  threshold (fires), other-key-during-hold (cancels), early release (cancels), and threshold
  boundary (fires at exactly the configured duration, not before).
- Manual test pass before considering M1 done: hotkey open/close latency, menu bar icon
  click, modifier-hold gesture at the real default duration, launching a handful of real apps,
  searching for real files, calculator edge cases (division by zero, malformed input), and
  confirming all three triggers can be individually disabled without affecting the other two.

### 4.6 Tooling & repo

- Swift + SwiftUI, macOS 14+ (matching `MacVoiceInput`'s baseline).
- XcodeGen (`project.yml`) for project generation — no committed `.xcodeproj` internals.
- New GitHub repo `connorodea/amani`, MIT license, public from the start (FOSS is the point).
- **Zero third-party dependencies for activation** — adapted directly from proven code already
  in `MacVoiceInput` (`GlobalHotkeyManager.swift`, `TripleCommandDetector.swift`,
  `PermissionManager.swift`), same author, no licensing concern:
  - `HotkeyTrigger` uses Carbon's `RegisterEventHotKey` directly (real key + modifier combo,
    e.g. Space+Cmd) — first-party API, no special permission required, no third-party hotkey
    library needed.
  - `ModifierHoldTrigger` uses a `CGEvent.tapCreate` listen-only event tap (bare modifier chord
    has no key code, so it can't go through `RegisterEventHotKey`) — this is the same mechanism
    MacVoiceInput's push-to-talk-via-modifier-chord and triple-command detector already use.
    **Requires Input Monitoring permission** (`CGPreflightListenEventAccess`/
    `CGRequestListenEventAccess`), distinct from Accessibility — same as MacVoiceInput.
  - `MenuBarTrigger` uses plain AppKit `NSStatusItem` — no permission needed at all.
  - Respects secure input (`IsSecureEventInputEnabled()`) the same way MacVoiceInput's
    detector does — `ModifierHoldTrigger` refuses to arm while a secure-input field (e.g. a
    password field) is focused, failing safe rather than firing.

## 5. Open questions carried into later milestones

- Exact log-capture strategy for *adopted* (not Amani-launched) agent processes — piped
  capture for Amani-launched processes is straightforward; tailing known log/transcript paths
  plus an `lsof`-based fallback for arbitrary adopted processes needs its own design pass in
  the M2 spec.
- Choice of open-source local vector store for M3 (candidates: `sqlite-vec`, `usearch`) —
  deferred to the M3 spec once M1/M2 are built and real query patterns exist to test against.
- Whether the knowledge graph in M3 is bespoke or adapts the existing `graphify` skill's
  approach — deferred to M3 spec.
