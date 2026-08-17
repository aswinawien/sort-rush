# Sort Rush

**Sort packages at an increasingly unreasonable speed, preserve your combo, and prove you can beat your own best run.**

A one-thumb parcel-sorting game for Android, built in Flutter and Flame. Packages ride a belt toward a sort line; you read each one and tap the bin it belongs in before it falls off the end. Miss three and the shift ends.

The identity is glitchy counterculture — a strange independent zine that learned to run a very precise arcade machine. Irregularity lives around the play field. Active gameplay stays calm, high-contrast, and legible.

## What it's for

A short-session score chaser for people who like one-thumb puzzle, timing, and sorting games. The design assumes a new player gives it thirty seconds before deciding, so the first action has to be obvious immediately and level 1 is impossible to fail.

It is also a deliberately constrained solo project. Every scope decision is written down in `docs/decision-log.md` and gated by a human before it becomes real. The constraints in `CLAUDE.md` are the point, not paperwork.

## Core loop

Observe a package → identify its destination → tap the bin → receive immediate feedback → manage speed and active packages → chase combo and score → restart after failure.

Difficulty comes from four data-driven numbers per level: read window, spawn interval, maximum active packages, and mistake limit. Two of them are fairness floors that will not be lowered without device-test evidence — a **1.2s** read window and a **0.65s** spawn interval. Below those, a first-time player cannot reliably read two attributes and act.

## Current status

**Milestone 4 — vertical slice — in progress.** Milestone 3 passed its gate on 2026-08-16. Home → Levels 1–10 → Results → Retry is playable end to end, with scoring, combo, game over, and restart.

- `flutter analyze` — clean
- `flutter test` — 265 passing
- `flutter build appbundle --release` — verified, 45.2 MB (~7 MB per device)
- Runs on Android — see `docs/screenshots/device/`

**Ten curated shifts ship**, plus endless. Level 10 teaches the `PRIORITY` override so endless is not a cliff. Endless grows, swaps, and opens a memo-board shop between blinds.

Mechanics live today: shape routing, the attribute switch to colour and pattern, combo tiers, queue pressure, clutch saves, compound routing, `DAMAGED`, `PRIORITY`, the endless shop, and a double-or-nothing results wager.

**Gate 4 is awaiting a ruling** — `docs/milestone-4-gate.md`. Onboarding and endless are evidenced. Persistence is unbuilt. Audio is approved and blocked. One developer play said it looks good; the fairness floors are still untimed. The recommendation is to hold, not to close.

## Getting started

Requires the Flutter stable channel, **3.41.0 or newer** (Flame 1.36.0 raised its floor).

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

For a release build:

```bash
flutter build appbundle --release
```

Portrait only, Android-first, fully offline. There are no accounts, no backend, and no network calls.

## Architecture

The one rule that shapes the codebase: **gameplay logic never imports the engine.**

```
lib/
  core/    scoring, combo, pass conditions, difficulty, routing rules,
           live run tuning, seeded RNG, run state machine
           — imports neither Flame nor Flutter
  game/    Flame rendering and input shell (belt, bins, sort line, HUD)
  ui/      Flutter navigation, overlays, briefing, pause, results
```

`test/core/no_engine_imports_test.dart` enforces the boundary as a test, so it fails loudly rather than eroding.

This buys two things. Scoring, combo, difficulty, seed replay, and state transitions are unit-testable with no game loop. And randomness stays seedable: a single `SeededRng` is owned by the run and injected, so the same seed plus the same input timeline reproduces a run exactly.

That RNG is a pinned xorshift32 rather than `dart:math`'s `Random` — deliberately, so a seed yields an identical sequence on every platform and every SDK version instead of inheriting whatever the SDK ships. `dart:math`'s `Random` is not used anywhere in the project.

Two rules keep randomness fair, and both are enforced by tests rather than by intention:

**Randomness resolves before a decision, never after.** A `DAMAGED` package shows a corrupted state for a telegraphed window *before* it changes, so the player can choose to wait. A silent change would punish a decision already committed to. Every future random element is held to the same test.

**A package's timing is fixed when it spawns.** Read window and telegraph live on the package, not read from the level each tick — so nothing that changes a run's difficulty partway through can speed up, or move the deadline of, something already in flight.

`lib/core/run_tuning.dart` is the single source of a run's live numbers, and the fairness floors are clamped there rather than in each thing that might change them. That makes "nothing can breach a 1.20s read window or a 0.65s spawn interval" structurally true instead of a rule everyone has to remember.

## Accessibility

Color is never load-bearing on its own. Every package hue is permanently paired with a fill pattern — solid, hatch, or dotted — and bins are outline silhouettes with a mono letter, carrying no identifying fill color. The whole game is playable with every hue rendered as identical gray.

## Scope ceiling

Hard limits for v1. Exceeding any of them requires a decision-log entry and a human gate.

| Dimension | Ceiling |
|---|---|
| Bins on screen | 3 curated; 2–4 in endless |
| Package shapes | 3 |
| Package colors | 3 (always paired with a fill pattern) |
| Rule modifiers (stamps) | 2 |
| Curated levels | 10 |
| Endless modes | 1 |
| Distinct screens | 4 (Home, Play, Results, Settings) |
| Backend calls | 0 |
| Third-party runtime packages | 3 (`flame`, `shared_preferences`, `audioplayers`) |
| Bundled art assets | 0 for prototype — procedural shapes and type only |

Explicitly excluded from v1: accounts, backend, multiplayer, online leaderboards, ads, premium currency, energy, story, complex inventory, procedural level generation, and any custom illustration dependency.

## Documentation

| Document | What it covers |
|---|---|
| `CLAUDE.md` | Project constitution — mission, non-negotiables, milestones |
| `AGENTS.md` | Handoff for coding agents — environment quirks, test gotchas, current state |
| `docs/product-brief.md` | Pitch, target player, risks, scope ceiling, discarded alternatives |
| `docs/design-system.md` | Visual direction, novelty budget, interaction and accessibility rules |
| `docs/design-spec.md` | Screen-by-screen specification and Flutter/Flame mapping |
| `docs/level-spec.md` | Curated levels 1–10, endless curve, difficulty parameters |
| `docs/audio-brief.md` | Soundtrack direction and per-level generation prompts |
| `docs/milestone-3-gate.md` | Gate 3: criteria, evidence, defects, and the rulings |
| `docs/milestone-4-gate.md` | Gate 4: awaiting ruling — hold recommended |
| `docs/screenshots/` | Web captures of every screen, plus real device captures |
| `docs/testing-strategy.md` | Test layers and quality bar |
| `docs/backlog.md` | Captured intent — not designed, not scheduled, not approved |
| `docs/depot-record.html` | Shift Record dashboard — generated from the decision log |
| `docs/decision-log.md` | Every meaningful decision, its evidence, and its gate status |

Meaningful decisions go in the decision log. A proposal is not approved until the human gate says so, and when evidence invalidates a decision the log gets a new entry — history is never rewritten.

## Milestones

1. **Concept** — pitch, core loop, target player, risks, scope ceiling — *closed*
2. **Design** — states, UI/UX, rules, onboarding, endless curve, technical handoff — *closed*
3. **Prototype** — one complete run, scoring, combo, game over, restart — *passed 2026-08-16*
4. **Vertical slice** — onboarding, endless, persistence, feedback, device test ← *current, Gate 4 awaiting ruling*
5. **Internal test** — signed AAB, listing basics, tester channel, release evidence

### Milestone 4 — still open

Shipped: curated 1–10, endless (grow / swap / shop / `PRIORITY`), double-or-nothing, a release AAB that builds.

Still required before Gate 4 can close:

1. **A human plays it.** Logged 2026-08-17 — developer, web, qualitative “looks good.” Questionnaire unanswered. Fairness floors still unmeasured.
2. **Persistence.** Best run via `shared_preferences`. The pitch is beating your own score and nothing stores one.
3. **Backgrounding and relaunch tests.** Backgrounding holds the belt and is tested. Killed-process relaunch needs persistence first.
4. **Audio.** Approved, blocked on Suno commercial terms recorded in the decision log. Mute must leave the game fully playable.
5. **A device playtest that counts.** Emulator smoke found three P1s; that is not the questionnaire in `docs/testing-strategy.md`.

Settings is budgeted and unbuilt. Quota / hazardous cargo / scanner stay designed-not-built.

### Milestone 5 — after Gate 4

Signed `appbundle` already verified. Remaining: store listing (copy, **device** screenshots, icon, content rating), Play internal-test track, release evidence.
