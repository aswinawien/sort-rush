# Agent handoff — Sort Rush

For any coding agent picking this up: Codex, Cursor, Claude Code, or a human doing an agent's job.

**This file is not the rules.** The rules are `CLAUDE.md` — the project constitution. Read it first; it overrides anything here. This file carries the things no other document records: environment quirks, hard-won testing knowledge, and where the work actually stands.

Keep this file current. If you finish a slice, update *Where things stand* before you sign off.

---

## The one thing most likely to go wrong

**This project is human-gated. Agents propose; they do not decide.**

Standalone `proposed` entries in `docs/decision-log.md` right now: Gate 4 outcome. Residuals still sit inside approved entries — home's one-tap promise at 2× text, and a few clutch-save deviations. Implementing one of those because it looks sensible is the single worst thing you can do here — it converts a pending decision into a fait accompli and the log stops being trustworthy.

- Do not implement a `proposed` decision.
- Do not change a decision's status. Only the human does that.
- Do not start a milestone whose gate has not been approved. Milestone 4 is open.
- If evidence invalidates a decision, **add a new entry**. Never rewrite history.

When you find something that needs a decision, write it up in `docs/decision-log.md` as `proposed` with context, options considered, and consequences — then stop.

---

## Environment

**`flutter` is not on `PATH`.** This costs every new agent a wasted cycle:

```bash
export PATH="$HOME/flutter/bin:$PATH"
```

Flutter 3.47.0 stable. The project floor is 3.41.0 (Flame 1.36.0 raised it).

```bash
flutter pub get
flutter analyze      # must stay clean — no issues, ever
flutter test         # 312 passing as of 2026-08-17
```

**Android builds run on the Windows side, not in WSL.** Flutter 3.47.0 is installed at `E:\flutter-sdk\flutter`, the Android SDK is at `C:\Users\aswin\AppData\Local\Android\Sdk`, and the repository is reachable from Windows as `E:\Game Dev\sort-rush` — the same files, no copying. Drive it from WSL through interop:

```bash
powershell.exe -NoProfile -Command "cd 'E:\Game Dev\sort-rush'; & 'E:\flutter-sdk\flutter\bin\flutter.bat' build appbundle --release"
```

**The two Flutter installs share one `.dart_tool/`, and whichever side ran last owns it.** Switching sides without `flutter clean && flutter pub get` produces a compiler error that names entirely the wrong culprit — `Method not found: 'TextSpan'` in `lib/game/text_util.dart`, on source that is correct. What actually happened is that `package_config.json` still pointed at the other OS's paths, so `package:flutter` resolved to nothing. **If you see undefined Flutter symbols in code that analyses cleanly, this is why.** Run `flutter pub get` on the side you are using — and be aware the recovery is sometimes worse than that. Measured on 2026-08-17: running `flutter analyze` from WSL against a Windows-owned `.dart_tool` reported **1339 issues**, and `flutter test` then refused to use a `build/` directory Windows had created, failing with `PathNotFoundException` on a path that plainly existed. That needed a full `flutter clean` plus `pub get`, not just a `pub get`. **Budget a clean rebuild when you switch sides, not a few seconds.**

`flutter build appbundle --release` was verified working on 2026-08-17. `flutter doctor` complains that `cmdline-tools` is missing and licences are unverifiable; Gradle reads the accepted licences fine, so this is cosmetic. Debug symbols are unstripped because no NDK is installed.

**There is no Android SDK inside WSL itself.** Linux-side `flutter build appbundle` will fail, and WSL has no USB passthrough. Use the Windows path above.

**The web build works and is how you see the game run:**

```bash
flutter build web --release --no-web-resources-cdn
cd build/web && python3 -m http.server 8731 --bind 127.0.0.1
```

Then open `http://localhost:8731`. On WSL2, localhost forwards to the Windows browser automatically. Use device emulation at 390×844 — it is a portrait one-thumb game and a desktop window misrepresents it badly.

Screenshots in `docs/screenshots/` were captured this way with headless Chrome and `puppeteer-core`, driven by coordinate taps because Flutter web paints to a canvas and has no DOM to click. They are layout evidence only, never device evidence.

---

## Architecture rules that are enforced by tests

**`lib/core` imports neither Flame nor Flutter.** `test/core/no_engine_imports_test.dart` fails if you break it. Do not weaken that test to make a change compile — the boundary is the main defence against the hidden coupling the product brief names as risk 4.

```
lib/core/   rules: scoring, combo, difficulty, routing, seeded RNG, run state machine
lib/game/   Flame rendering and input shell — holds no rules
lib/ui/     Flutter navigation, briefing, pause, results
```

Anything that decides an outcome belongs in `core/`. If you are reaching for game state inside a component, you are in the wrong layer.

**Randomness is `SeededRng` only.** It is a pinned xorshift32, deliberately not `dart:math`'s `Random`, so a seed produces identical output across platforms and SDK versions. `dart:math`'s `Random` appears nowhere in this project and must stay that way — same seed plus same input timeline reproduces a run exactly, and that is an acceptance criterion.

**Difficulty is data.** Level parameters live in `lib/core/levels.dart` and are asserted against `docs/level-spec.md` by `test/core/levels_test.dart`. Change the doc and the data together, or the test will tell you.

---

## Writing tests here — read this before you write one

Widget tests around Flame have sharp edges. These are all discovered the hard way and are why the existing tests look the way they do.

**Never call `pumpAndSettle()` while a Flame `GameWidget` is mounted.** The game loop schedules a frame every frame, so it never settles and the test times out. Use explicit `await tester.pump(Duration(...))`. `pumpAndSettle` is safe only on the briefing, results, and home screens, where no game exists.

**After any tap that reaches Flame, pump at least 100ms.** Flame's multi-tap recognizer arms a 40ms countdown on pointer-down; ending a test inside that window leaves a pending timer and the test fails.

**`ResultsScreen` types the manifest** — 24ms per character, a pause between lines, plus a 500ms cursor blink timer. Both cancel when printing finishes or the player taps the `skip-manifest` overlay. Do not pump ~500ms and hope; that no longer finishes the slip. Pump ~8s of fake time, tap `skip-manifest`, or set `MediaQuery.disableAnimations`. Otherwise the test ends with a timer pending.

**Booting the game needs three pumps**, because `onLoad` is async:

```dart
await tester.pump();
await tester.pump();
await tester.pump(const Duration(milliseconds: 16));
```

**Getting the live game out of the tree:**

```dart
tester.widget<GameWidget<SortRushGame>>(
  find.byType(GameWidget<SortRushGame>),
).game!
```

**Level 1 is the easiest to script** — single full-width chute, one shape, unfailable. Any tap in the bin band is correct. Level 2 is the first failable level (three chutes, three mistakes), so it is where game-over scenarios go.

**Performance**: `tool/benchmark_core.dart` benchmarks the simulation headless (`~/flutter/bin/dart run tool/benchmark_core.dart`); `test/perf/render_cost_test.dart` prints a per-component paint breakdown. The simulation is free — roughly 0.1us/frame — so do not optimise `lib/core` without evidence. Neither harness sees the GPU, so neither is evidence of 60fps on a device.

**Test layers** are defined in `docs/testing-strategy.md`. Layer 4 lives in `test/scenarios/` and drives whole runs through the real widget tree — that is where acceptance-criteria evidence belongs, not in unit tests.

---

## Where things stand

*Last updated 2026-08-22, on `feature/immersive-mode`.*

**Milestone 4 is in progress. Gate 4 is not closed.** Evidence: `docs/milestone-4-gate.md`. Recommendation: hold. Do not start Milestone 5.

**Just shipped:** visual/audio slice is committed on `feature/immersive-mode`. Immersive Neon is a presentation toggle, default off. Shop overlay now holds `engine.update` until the paper retracts (criterion 8). Neon wake clips at 10px so it does not rely on the spawn floor. Active-package trails stay rejected. Lobby music still dies on return-to-Home (QA-R2-01). Music files: 10 of 14 OGGs; `l07`/`l08`/`l10`/`results.ogg` still missing.

**First human play (2026-08-17):** developer, web, verdict "looks good", no P0/P1 named. Questionnaire unanswered. Fairness floors still untimed. This is not the device test and does not close Gate 4.

**Still approved and unbuilt:** the four missing music files (`l07`, `l08`, `l10`, `results.ogg`). Quota contracts, hazardous cargo, and the scanner reveal remain designed-not-built.

**Bins ceiling** is 3 curated, 2–4 endless. Routing during an endless run must go through `engine.binFor` / `liveBinCount`, never `level.routing.binFor`. Shop RNG is `SeededRng(seed ^ 0x51A70FF)` — never the engine stream.

**What closes Milestone 4, in order, if the gate is held:**

1. A device playtest that fills the questionnaire and times the 1.20s / 0.65s floors. Music is in; Immersive Neon stays default-off until that session also times it.
2. Drop `l07`/`l08`/`l10`/`results.ogg` when they exist — filenames are already wired.

**Then Milestone 5:** listing basics, Play internal-test track, release evidence. The signed AAB already builds. Do not start M5 before Gate 4 closes.

**Do not start quota contracts, hazardous cargo, or the scanner unless the human asks.** Do not invent unlock-gating endless. Do not invent a Settings screen for mute — it already lives on Home.

---

## If you are asked to "improve" this project

The temptation is to add features. Resist it. In rough order of what actually helps:

1. **Coverage that still has no test** — killed-process relaunch of a full run. Scores now survive a fresh store; the belt itself still does not.
2. **Never** add monetization. The constitution forbids it until repeat play is demonstrated by human testing. The first play is logged; that is not yet the repeat-play evidence this rule wants.

Every task report must include: current state, goal, evidence, proposed action, files to change, tests to run, risks, explicit non-goals, approval status, and decision-log update. That list is from `CLAUDE.md` and it is not optional.

---

## Document map

| File | What it is |
|---|---|
| `CLAUDE.md` | The constitution. Mission, non-negotiables, milestones. Read first. |
| `docs/decision-log.md` | Every decision, its evidence, its gate status. The project's memory. |
| `docs/milestone-3-gate.md` | Gate 3, closed 2026-08-16: criteria, evidence, defects, and the rulings. |
| `docs/milestone-4-gate.md` | Gate 4, awaiting ruling: criteria, evidence, gaps, and the options. |
| `docs/product-brief.md` | Pitch, target player, risks, scope ceiling, discarded alternatives. |
| `docs/design-system.md` | Visual direction, novelty budget, interaction and accessibility rules. |
| `docs/design-spec.md` | Screen-by-screen spec, Flutter/Flame mapping, open questions in §12. |
| `docs/level-spec.md` | Levels 1–10, endless curve, difficulty parameters, fairness floors. |
| `docs/backlog.md` | Captured intent that is not designed and not scheduled. Not approved, not buildable as written. |
| `docs/audio-brief.md` | Soundtrack direction and Gemini/Lyria prompts. Production material, not a decision. SFX are synthesised; music waits on files. |
| `docs/testing-strategy.md` | Test layers, required scenarios, bug format, severity rubric. |
| `docs/screenshots/` | Web captures of every screen. Layout evidence, not device evidence. |
| `docs/depot-record.html` | Shift Record dashboard, generated from the decision log. |
