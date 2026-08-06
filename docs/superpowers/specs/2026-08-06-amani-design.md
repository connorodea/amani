# Amani — Design Spec

**Date:** 2026-08-06
**Status:** Approved for M1 implementation planning
**Repo:** `connorodea/amani` (to be created on GitHub, MIT license)

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
├── AppDelegate            — lifecycle, global hotkey registration, panel show/hide
├── OverlayWindow (NSPanel)— borderless, floating, centered, key window on activate
├── SearchView (SwiftUI)   — text field + results list, Spotlight-style
├── SearchController       — owns query state, debounces input, fans out to providers
├── Result Providers        (protocol-based, so M2+ providers slot in identically)
│   ├── AppLauncherProvider — enumerates + launches .app bundles via NSWorkspace
│   ├── FileSearchProvider  — shells out to `mdfind` for Spotlight-indexed file search
│   └── CalculatorProvider  — local expression evaluation, no shell-out
├── HotkeyManager           — global hotkey capture (Cmd+Space), via an existing
│                             open-source Swift hotkey library rather than hand-rolled
│                             Carbon/Quartz event-tap code
└── SetupAssistant          — first-run flow: Accessibility permission, guided steps to
                              disable Spotlight's own Cmd+Space binding in System Settings
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

- **HotkeyManager**: registers Cmd+Space as a global hotkey. On first launch, detects whether
  macOS Spotlight still owns that binding (best-effort, via reading the user's Symbolic
  HotKeys plist) and — if so — walks the user through disabling it in System Settings >
  Keyboard Shortcuts (Apple provides no API to do this programmatically; it's a guided manual
  step, done once).
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
- **SetupAssistant**: run once on first launch; requests Accessibility permission (needed for
  the global hotkey + eventually for agent process control in M2), and hands off to the guided
  Spotlight-disable step.

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
- If Accessibility permission is denied, the app still launches and shows the panel via a
  fallback in-app menu-bar icon click (hotkey won't work without it) with a persistent nudge
  to grant permission.
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
- Manual test pass before considering M1 done: hotkey open/close latency, launching a handful
  of real apps, searching for real files, calculator edge cases (division by zero, malformed
  input).

### 4.6 Tooling & repo

- Swift + SwiftUI, macOS 14+ (matching `MacVoiceInput`'s baseline).
- XcodeGen (`project.yml`) for project generation — no committed `.xcodeproj` internals.
- New GitHub repo `connorodea/amani`, MIT license, public from the start (FOSS is the point).
- Global hotkey capture uses an existing, actively-maintained open-source Swift library
  (e.g. `HotKey`) rather than hand-rolled Carbon event-tap code — in line with the
  build-with-existing-FOSS-tools steer for this project generally.

## 5. Open questions carried into later milestones

- Exact log-capture strategy for *adopted* (not Amani-launched) agent processes — piped
  capture for Amani-launched processes is straightforward; tailing known log/transcript paths
  plus an `lsof`-based fallback for arbitrary adopted processes needs its own design pass in
  the M2 spec.
- Choice of open-source local vector store for M3 (candidates: `sqlite-vec`, `usearch`) —
  deferred to the M3 spec once M1/M2 are built and real query patterns exist to test against.
- Whether the knowledge graph in M3 is bespoke or adapts the existing `graphify` skill's
  approach — deferred to M3 spec.
