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

**Milestone 3 — prototype.** Home → Levels 1–3 → Results → Retry is playable end to end, with scoring, combo, game over, and restart.

- `flutter analyze` — clean
- `flutter test` — 63 passing

Levels 4–10, endless mode, onboarding, persistence, and sound are Milestone 4. Several decision-log entries are still `proposed` and waiting on the Gate 3 review.

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
  core/    scoring, combo, difficulty, routing rules, seeded RNG,
           run state machine — imports neither Flame nor Flutter
  game/    Flame rendering and input shell (belt, bins, sort line, HUD)
  ui/      Flutter navigation, overlays, briefing, pause, results
```

`test/core/no_engine_imports_test.dart` enforces the boundary as a test, so it fails loudly rather than eroding.

This buys two things. Scoring, combo, difficulty, seed replay, and state transitions are unit-testable with no game loop. And randomness stays seedable: a single `SeededRng` is owned by the run and injected, so the same seed plus the same input timeline reproduces a run exactly.

That RNG is a pinned xorshift32 rather than `dart:math`'s `Random` — deliberately, so a seed yields an identical sequence on every platform and every SDK version instead of inheriting whatever the SDK ships. `dart:math`'s `Random` is not used anywhere in the project.

## Accessibility

Color is never load-bearing on its own. Every package hue is permanently paired with a fill pattern — solid, hatch, or dotted — and bins are outline silhouettes with a mono letter, carrying no identifying fill color. The whole game is playable with every hue rendered as identical gray.

## Scope ceiling

Hard limits for v1. Exceeding any of them requires a decision-log entry and a human gate.

| Dimension | Ceiling |
|---|---|
| Bins on screen | 3 |
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
| `docs/product-brief.md` | Pitch, target player, risks, scope ceiling, discarded alternatives |
| `docs/design-system.md` | Visual direction, novelty budget, interaction and accessibility rules |
| `docs/design-spec.md` | Screen-by-screen specification and Flutter/Flame mapping |
| `docs/level-spec.md` | Curated levels 1–10, endless curve, difficulty parameters |
| `docs/testing-strategy.md` | Test layers and quality bar |
| `docs/decision-log.md` | Every meaningful decision, its evidence, and its gate status |

Meaningful decisions go in the decision log. A proposal is not approved until the human gate says so, and when evidence invalidates a decision the log gets a new entry — history is never rewritten.

## Milestones

1. **Concept** — pitch, core loop, target player, risks, scope ceiling
2. **Design** — states, UI/UX, rules, onboarding, endless curve, technical handoff
3. **Prototype** — one complete run, scoring, combo, game over, restart, no P0/P1 bugs ← *current*
4. **Vertical slice** — onboarding, endless mode, persistence, feedback, device test
5. **Internal test** — signed AAB, listing basics, tester channel, release evidence
