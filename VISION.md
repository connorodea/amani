# Amani — Vision

> One-sentence north star: Amani is the nervous system of your Mac — a single command bar
> (the reflex arc) backed by a central brain that finds anything and commands every agentic
> process and connected tool, the way OpenRouter is the unified router for models.

_Last updated: 2026-08-06 · Version: v2_

**Brand:** The product name is **Amani** — full stop, everywhere: the app, the company, the
ecosystem. `ainervousystem.com` is a memorable, easy-to-say redirect domain that will point to
wherever Amani actually lives (marketing site, then the app); it is not a second brand. As of
2026-08-06 it points its DNS at the `hetznerLR` box (178.156.172.208) as a placeholder — **no
Amani site is deployed there yet**, so the domain doesn't resolve to real Amani content until
that's built.

## What it is

A native macOS, FOSS application that takes over Cmd+Space from Apple Spotlight. It does
everything Spotlight does (launch apps, find files, quick math) and, layered on top, becomes
a unified control plane for every agentic process running on the machine — start, stop,
attach, watch logs, and (later) semantically search across all of it in natural language.
One command bar, one hotkey, two jobs that turn out to be the same job: "find and act on
the thing I mean, right now."

## Who it's for

Connor: a power user who runs many concurrent agentic processes (Claude Code sessions,
`/loop`s, `/autonomous` runs, background Task agents, cron-scheduled agents) across dozens of
repos and git worktrees simultaneously, and who currently has no single place to see "what's
running, where, doing what" short of switching terminals or checking `/fleet-status` by hand.
Secondarily: any FOSS-minded macOS power user running multiple agentic CLIs (Claude Code,
Codex, Gemini CLI, Cursor, OpenClaw, custom scripts) who wants one control surface instead of
N terminal tabs.

## The problem

Two problems that turn out to share a UI:

1. **Spotlight is a dead end for extension.** There's no supported way to make Apple's own
   Spotlight agent-aware — the only way to build "Spotlight, but smarter" is to become the
   thing Cmd+Space opens.
2. **Agentic work has no command center.** As agent usage scales (multiple concurrent loops,
   workflows, worktrees, repos), the operator's only visibility is scattered across terminal
   panes, `/fleet-status` snapshots, and memory. There's no single place to search "what's
   Amani doing right now" the way you'd search for a file.

## Core value proposition

One hotkey, one bar, natural language in, the right result out — whether "the right result"
is opening Xcode, finding last week's PDF, or checking on the `/autonomous` run in `juricrat`.
Agent control must feel exactly as instant and low-friction as launching an app, because
that's the bar Spotlight already set.

## Design philosophy

Two design languages run through every milestone, from architecture down to pixels:

**The nervous system metaphor (system architecture).** Amani is the CNS — a brain (routing
and decision logic) plus a spinal cord (one shared signal pipeline everything flows through:
already the `ResultProvider` fan-out in M1, extended to agent connectors in M2 and the
semantic layer in M3). Connected tools — Visualized (notes/PKM), future apps — are organs on
the peripheral nervous system: autonomous locally, but they speak Amani's signal protocol to
report state and receive commands, the same pluggable-connector shape already used for agent
providers. This yields one concrete, non-metaphorical engineering rule: **separate reflex
paths from cognitive paths.** Reflex actions (launch this app, open this file, toggle that
agent) are fast, local, deterministic — no LLM in the loop, matching M1/M2. Cognitive actions
(natural-language search, relationship tracing) are slower and route through the "brain" —
matching M3. Never blur the two: a reflex action that silently starts depending on a network
call or an LLM response is a regression, not a feature.

**Golden ratio + classical precision (visual + engineering discipline).** The visual design
system (panel proportions, type scale, spacing scale) is built on φ (1.618) the way classical
typography and architecture use it — this is a concrete rule for the UI/UX pass, not a
metaphor: every M1+ interface spec should derive its scale from φ rather than picking numbers
by feel. The engineering discipline this pairs with is the same rigor Keel enforces
elsewhere in this ecosystem: nothing ships loose, every constraint is explicit and checked,
precision over speed when the two trade off. "Ancient Greek mathematician" is the standard —
elegant, minimal, nothing left to chance.

## Principles / non-negotiables

- **Must never regress core Mac usability.** Losing Spotlight's baseline (app launch, file
  search) for even one release is not acceptable — M1 ships full baseline parity before any
  agent features.
- **Generic and pluggable, not Claude-Code-specific.** The process-discovery and connector
  layers are architected so any agentic CLI can be a provider; Claude Code is the first
  target, never a hardcoded assumption baked into the core.
- **FOSS and privacy-respecting by default.** MIT license, public repo, no telemetry. Local
  processing is the no-setup default wherever a local/cloud choice exists (e.g. embeddings in
  M3); cloud options are opt-in, never required to use the app.
- **Compose existing open-source tools over reinventing them.** Global hotkey capture, file
  search, vector storage — reach for a proven FOSS library or a bash/CLI system tool (`mdfind`,
  `ps`, `lsof`, `launchctl`) before writing bespoke low-level code.
- **Non-goal: a marketplace of unrelated launcher workflows.** Amani is not trying to be a
  general Alfred-workflow clone — agent control is the differentiator; launcher parity is
  table stakes, not the product.
- **Non-goal: replacing terminals entirely.** Amani surfaces and controls agent processes; it
  is not trying to become a full terminal emulator or IDE.

## Main workflows

1. **Instant launch/find** — Cmd+Space, type a few characters, hit Enter: app opens, file
   opens, or a calculation resolves. (M1)
2. **Check on an agent** — Cmd+Space, type a project or agent name, see its live state
   (running/idle/done) inline in the same results list as everything else. (M2)
3. **Act on an agent** — from that same result, start, stop, or attach/view logs without
   leaving the bar or switching to a terminal. (M2)
4. **Ask in plain language** — "what's still running in juricrat" or "find that PDF about the
   Renovo term sheet" returns the right result even without exact-name matching. (M3)
5. **Trace relationships** — follow a result from an agent to the project, files, and past
   tasks it touched, via the knowledge graph. (M3)

## System modules

- **OverlayWindow / SearchView** — the floating Spotlight-style command bar (M1)
- **ActivationManager** — every way to summon Amani, each independently toggleable: global
  hotkey combo (default Cmd+Space), modifier-hold gesture (default: hold Cmd alone 5s), and
  a persistent menu bar icon — plus guided Spotlight-disable setup (M1)
- **SearchController** — query fan-out, debounce, merge/rank across all providers (M1)
- **Result Providers** (protocol-based, uniform across all milestones):
  - AppLauncherProvider, FileSearchProvider, CalculatorProvider (M1)
  - Agent process providers, generic-scan discovery (M2)
  - Semantic/embedding-backed provider (M3)
- **Process control layer** — start/stop/attach, hybrid log capture (piped for
  Amani-launched, tailed/`lsof`-discovered for adopted processes) (M2)
- **Semantic index** — pluggable embeddings (local default, cloud optional), open-source
  local vector store, relational knowledge graph (M3)
- **Connector ecosystem** — additional provider integrations beyond Claude Code (M4)

## Data model implications

- **SearchResult** — provider id, title, subtitle, icon, action, rank score (M1, extended
  each milestone with richer metadata: agent state, log excerpt, related-entity links).
- **Agent process record** — discovered process, provider/backend type, state, launch
  origin (Amani-launched vs. adopted), log source location (M2).
- **Knowledge graph entities** — agent ↔ project ↔ file ↔ task, with relational edges the
  semantic layer traverses for "trace relationships" (M3).

## UI/UX implications

- Must render and respond at Spotlight speed — any perceptible lag on keystroke breaks the
  product's core promise.
- Agent results must be visually distinguishable from launcher results (state indicator,
  distinct icon treatment) without needing a separate mode or tab — one unified list.
- Log viewing / process actions happen inline or via a lightweight expansion, not a full
  context switch to another window.

## MVP boundary

**In (M1):** Cmd+Space takeover, floating overlay, app launch, file search (`mdfind`-backed),
calculator, guided Spotlight-disable setup, FOSS repo scaffold.
**Out (for now):** All agent control (M2), semantic/NL search and knowledge graph (M3),
additional provider connectors, clipboard history, snippets, plugin system (M4).

## Roadmap (vision → milestones)

- **Now:** M1 — Foundation. Spec written (`docs/superpowers/specs/2026-08-06-amani-design.md`),
  implementation plan next.
- **Next:** M2 — Agent Command Center. Generic process discovery + hybrid log capture design
  still open (see Open Questions in the M1 spec).
- **Later:** M3 — Semantic Search + Knowledge Graph (pluggable local/cloud embeddings, local
  vector store, relational graph). M4 — Ecosystem (more connectors, clipboard/snippets,
  plugins, public FOSS launch polish).

## How to decompose this

Each milestone above is one spec → plan → build cycle (per the `brainstorming` →
`writing-plans` flow already in use). Within a milestone, decompose into the sub-goals implied
by its "System modules" entries above — e.g. M1 splits cleanly into ActivationManager+OverlayWindow
(shell), then the three M1 result providers (can build in parallel once the `ResultProvider`
protocol is fixed). Track milestone-level work in a `GOALS.md` (via the `northstar` skill) if/when
the backlog grows past what a single spec's task list can hold; day-to-day tasks can live in
Todoist once a tracker is set up for this repo, matching the pattern used on your other projects.

## Open questions

- Exact adopted-process log-capture strategy for M2 (piped vs. tailed vs. `lsof`-fallback) —
  flagged in the M1 spec, needs its own design pass before M2's spec is written.
- Local vector store choice for M3 (`sqlite-vec` vs. `usearch` vs. other) — deferred until
  M1/M2 exist and real query patterns can inform the choice.
- Whether M3's knowledge graph is bespoke or adapts the existing `graphify` skill's
  god-node/community-detection approach — deferred to the M3 spec.
- Whether Amani ever needs macOS Accessibility-level UI automation (e.g. to detect an agent's
  permission-prompt state in a terminal it didn't launch) — not yet scoped; would be a
  significant added-permission surface if it comes up in M2.
- **Visualized** (working name) — a notes/PKM tool ("focus: Obsidian, not Notion") that
  captures thoughts while you work and connects to Amani as a peripheral-nervous-system
  "organ" — first surfaced 2026-08-06 from a Safari-tab-snapshot experiment. Not yet spec'd.
  Naming collision to resolve first: `~/developer/visualized` already exists as an unrelated
  Canva-style templates SaaS repo — needs a real decision (rename one, or pick a different
  name for the PKM tool) before this becomes a repo of its own.
- Where and how `ainervousystem.com` actually serves Amani content (redirect vs. reverse
  proxy vs. dedicated landing page on `hetznerLR`) — DNS points there as of 2026-08-06, no
  site exists yet. **Update 2026-08-06:** resolved for now — a golden-ratio-proportioned
  "Amani M1" placeholder is live at https://ainervousystem.com (HTTPS, `hetznerLR`,
  `/var/www/amani-placeholder`) until the real app/marketing site exists.
- **CATO** (`~/developer/ChiefArchitectOfficer`, domain `chiefarchitectofficer.com`) — an
  already-mature, separate project ("the auditory command center for agentic architecture":
  voice-first supervision of multiple concurrent agent harnesses, visual portal for
  intervention). Direction as of 2026-08-06: CATO becomes a handheld voice device that
  integrates directly with Amani M1, with **Amani M1 as its local access point**. Not yet
  scoped — needs its own design pass grounded in CATO's existing vision.md/northstar.md/specs
  before any integration work starts.
- **Saddlepoint** — working name for the cloud-hosted counterpart to Amani M1, integrating
  directly with it (local app ↔ cloud service split). Named 2026-08-06; not yet scoped.
- **Ehf** ("E = Hf" — the Planck-Einstein relation, energy as frequency) — working name for
  "the engine," Amani's core routing/decision component (the "brain" in the nervous-system
  metaphor). Named 2026-08-06; not yet scoped — which layer this actually names (the M1
  SearchController, a future cross-ecosystem reasoning core, or something else) needs
  clarifying before it's built.

## Changelog

- 2026-08-06 v3 — Replaced single-hotkey `HotkeyManager` with `ActivationManager`, owning
  three independently-toggleable triggers: hotkey combo, modifier-hold gesture (hold Cmd
  alone 5s by default), and a persistent menu bar icon. Menu bar icon now also serves as the
  reliability fallback when Accessibility permission is denied.
- 2026-08-06 v2 — Added Design philosophy (nervous-system architecture metaphor + golden
  ratio/classical-precision visual and engineering discipline). Reframed north star around
  Amani as the ecosystem's nervous system, not just a launcher. Documented the
  `ainervousystem.com` brand-redirect domain (points at `hetznerLR`, no site yet). Added
  Visualized (notes/PKM companion tool) as an open ecosystem thread with its naming
  collision flagged.
- 2026-08-06 v1 — Initial vision, distilled from the brainstorming session that produced the
  M1 design spec. Milestone roadmap (M1–M4) carried over from that spec's section 3.
