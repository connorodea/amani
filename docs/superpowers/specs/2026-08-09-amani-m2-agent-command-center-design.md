# Amani M2 — Agent Command Center — Design Spec

**Date:** 2026-08-09
**Status:** Draft — presented for review, not yet approved for implementation planning
**Depends on:** M1 (`docs/superpowers/specs/2026-08-06-amani-design.md`), shipped as
`feat/m1-foundation` (PR #1, not yet merged — merge is gated on Connor's UI confirmation,
independent of this spec)

## 0. How this spec was produced

Standing session directive is Auto Mode ("make the reasonable call and keep going" rather
than pausing for each clarifying question), reinforced by an explicit "continue
autonomously." The design decisions below are calls I made directly, grounded in M1's
existing architecture and the M2 roadmap line from the M1 spec ("generic process discovery
for agent CLIs, start/stop/attach, hybrid log capture, live agent state in the results
list"), rather than gathered through the usual one-question-at-a-time interview. Treat this
as a strong draft to react to, not a negotiated design — redirect anything that's wrong
rather than treating it as already-settled.

## 1. Concept (unchanged from M1's framing)

M2 is Amani's actual differentiator: "OpenRouter for agents, as a command center." Where M1
made Amani a Spotlight replacement, M2 makes it a control plane for every agentic process
running on the machine — discover them, see their live state, start new ones, stop or attach
to existing ones, all from the same overlay.

## 2. A real spec-vs-implementation deviation from M1, carried forward deliberately

M1's design spec declared `ResultProvider.results(for:)` as `async`. The **shipped M1 code**
made it synchronous (`func results(for query: String) -> [SearchResult]`,
`Sources/Amani/Providers/ResultProvider.swift:26`) — a deliberate implementation-time
decision (recorded as load-bearing during M1's build) that every M1 provider and
`SearchController`'s concurrent fan-out logic is now built around. **M2 must not silently
reintroduce `async` into that core protocol** — it would touch already-shipped, tested,
PR'd M1 code for no M2-specific reason. See §4 for how M2's genuinely async needs (process
discovery, log tailing) are handled as an additive layer instead.

## 3. Non-goals (M2-specific, in addition to M1's standing non-goals)

- Not a full process manager / Activity Monitor replacement — Amani surfaces *agent* CLI
  processes specifically (heuristically identified), not every process on the machine.
- Not a terminal emulator — "attach" does not mean Amani renders a live TTY. It hands off to
  the process's *owning* terminal window, or (for adopted processes with no capturable
  stdout) shows recently-tailed log lines read-only inside Amani.
- No process supervision/auto-restart — "stop" sends a signal and reports the result; it
  does not babysit the process afterward.
- Claude Code is the only agent CLI M2 ships heuristics for. The discovery/connector layer
  stays generic (per M1's own non-goals), but M2 does not attempt Codex/Gemini/Cursor
  support — that's explicitly M4 ("additional provider connectors").

## 4. Architecture

### 4.1 New components

```
AgentProcessProvider: ResultProvider   — process discovery, synchronous per-query scan
AgentProcessRegistry                   — owns the live-state side-channel (see 4.3)
LogCapture (protocol)
  ├── PipedLogCapture                  — Amani-launched processes: direct stdout/stderr pipe
  └── TailedLogCapture                 — adopted processes: known-path tailing + lsof fallback
ProcessControl                         — start (spawn + register), stop (signal + confirm),
                                          attach (focus owning terminal / show tailed log)
```

`AgentProcessProvider` conforms to the existing, unmodified, synchronous `ResultProvider`
protocol — a query still returns a plain `[SearchResult]` synchronously, same as
`AppLauncherProvider`/`FileSearchProvider`. Discovery itself (`ps`-equivalent enumeration +
heuristic matching) is fast enough to run synchronously on the existing per-provider
`DispatchQueue.global` fan-out, matching `FileSearchProvider`'s `mdfind` shell-out pattern.

### 4.2 Process discovery

Enumerate processes via `sysctl` (`KERN_PROC_ALL`, matching the low-level, no-extra-permission
approach `Process`/`ps` itself uses under the hood — avoids shelling out to `ps` per query).
For each process, apply heuristics in order:
1. **Known binary name match** — `claude`, `claude-code` (extensible list, config-driven, not
   hardcoded to just these two — M4 adds more without touching this matching logic).
2. **Argument/cwd inspection** (`proc_pidinfo`/`proc_pidpath` + `sysctl` for argv) — catches
   `node .../claude-code/...` or similar wrapped invocations the binary-name check misses.
3. Each match becomes a `SearchResult` with a distinct `SearchResultAction` case (new:
   `.controlAgentProcess(pid:)`, alongside M1's `.launchApp`/`.openFile`/`.copyToClipboard`),
   surfaced with live state (§4.3) in its subtitle (e.g. "Running · 2m34s · last activity 4s
   ago" vs. "Idle · waiting for input").

### 4.3 Live state — additive, not a `ResultProvider` protocol change

The core tension: `ResultProvider.results(for:)` is pull-based (fires per keystroke via
`SearchController`'s existing debounce). Live agent state (a process's status changing
between keystrokes) needs a push path. Rather than making the core protocol async/reactive
(which would ripple into every M1 provider for no M1 benefit), M2 adds a narrow,
**opt-in** side-channel:

```swift
protocol LiveUpdatingProvider: ResultProvider {
    var liveUpdates: AnyPublisher<Void, Never> { get }  // "something changed, re-query me"
}
```

`SearchController` gains a small, additive change: on init, it subscribes to
`liveUpdates` for any provider that offers it (checked via `as? LiveUpdatingProvider`) and
re-runs `performSearch(currentQuery)` when a tick arrives — the exact same code path a new
keystroke already triggers, just retriggered by a timer/file-watcher instead of typing.
`AgentProcessProvider` publishes a tick every ~1.5s *only while the overlay is visible and a
process-control query is active* (not a background always-on timer) via `Timer` + Combine —
matching M1's existing pattern of triggers/timers scoped to visible-and-active state (c.f.
`ModifierHoldTrigger`'s poll `Timer`). This is the only new moving part in `SearchController`
— every other M1 provider is completely unaffected (they simply don't conform to
`LiveUpdatingProvider`).

### 4.4 Hybrid log capture — resolves M1's explicitly flagged open question

- **Amani-launched processes** (via a new "start" action — see §4.5): `Process` with
  `standardOutput`/`standardError` set to `Pipe()`, read incrementally on a background
  queue (same `FinishGate`-style discipline already established in `FileSearchProvider`'s
  `ProcessShellRunner` for not leaking/deadlocking on pipe reads). Full, reliable capture —
  this is the easy case the M1 spec already anticipated.
- **Adopted processes** (already running before Amani discovered them): two-tier fallback,
  in order:
  1. **Known transcript path tailing** — for Claude Code specifically, tail
     `~/.claude/projects/<slug>/*.jsonl` (the same session-transcript files this very
     session's own transcript lives in) via `DispatchSource.makeFileSystemObjectSource`
     (kqueue-based, no polling). Structured, reliable, but only works for CLIs with a known,
     documented transcript location.
  2. **`lsof`-based fallback** for anything without a known path: `lsof -p <pid>` to find open
     file descriptors, heuristically filter to log-like paths (extension/name patterns:
     `*.log`, `*transcript*`, recently-modified files under the process's cwd), tail the
     best candidate the same way. Best-effort — reports "no capturable output found" rather
     than guessing wrong, per M1's established "fail safe, don't fabricate" pattern
     (mirrors `ModifierHoldTrigger`'s secure-input fail-safe).

### 4.5 Start / stop / attach — the three process-control actions

- **Start**: user types e.g. `claude /path/to/project` in Amani's search field.
  `AgentProcessProvider` recognizes the known-binary-name prefix and offers a
  "Start Claude Code here" result. Selecting it spawns via `Process` (piped capture, §4.4)
  and immediately registers the new process with `AgentProcessRegistry` so it shows as a
  live, running result on the next query.
- **Stop**: selecting a running agent-process result's secondary action (not the default
  Return action, to avoid an accidental kill on Enter) sends `SIGTERM`; a repeat within a
  short window escalates to `SIGKILL` (same two-stage pattern common in `kill`/Activity
  Monitor). No auto-restart, no confirmation dialog beyond the two-stage timing itself —
  matches M1's overall "fast, keyboard-first, no modal interruptions" feel.
- **Attach**: for a process with a discoverable owning Terminal/iTerm window (via AX window
  enumeration, matching techniques already used elsewhere this session for Amani's own
  verification), bring that window to the front. If no owning terminal window can be found
  (headless/backgrounded process), show the tailed log (§4.4) read-only inside Amani's
  results detail area instead of failing silently.

## 5. Data flow

```
AgentProcessProvider.results(for:) [sync, per-query]
  → sysctl process enumeration → heuristic match → SearchResult (+ live-state subtitle)

AgentProcessRegistry [the live-state side channel]
  → per-tracked-process: LogCapture (Piped | Tailed) → last-activity timestamp + status
  → Timer tick (~1.5s, overlay-visible-only) → liveUpdates publisher fires
  → SearchController re-runs performSearch(currentQuery) → results refresh with new state

ProcessControl.start/stop/attach
  → start: Process spawn + PipedLogCapture + register
  → stop: kill(pid, SIGTERM|SIGKILL)
  → attach: AX window focus, or fall back to showing TailedLogCapture output
```

No network egress, no telemetry — matches M1's standing non-goals. Everything is local
process introspection.

## 6. Testing

Mirrors M1's established pattern: protocol-based dependency injection so process
enumeration/signal-sending/AX calls are fakeable in tests (`AgentProcessProvider(enumerator:
FakeProcessEnumerator)`, matching `AppLauncherProvider(enumerator: AppEnumerating)`'s
existing shape). `LiveUpdatingProvider`'s publisher is tested by injecting a manually-fired
subject instead of a real `Timer`. Log-capture tailing is tested against a fixture file plus
a `DispatchSource` fake, not real process I/O, matching `FileSearchProvider`'s
`ShellRunning`-fake pattern.

## 7. Open questions carried into M3/M4 (unchanged from M1's list, still deferred)

- Local vector store choice, knowledge-graph approach — both explicitly M3, not touched here.
- Additional agent CLI connectors beyond Claude Code — explicitly M4.

## 8. New open question this spec surfaces

- **Should "start" support arbitrary shell commands, or only recognized agent-CLI binaries?**
  This draft scopes "start" narrowly (recognized binaries only) to stay inside M2's own
  non-goal of not becoming a general command launcher — but this is a real product-shape
  call, flagged rather than silently assumed, since a broader "run anything" start action
  would be a meaningfully different (and larger) feature.
