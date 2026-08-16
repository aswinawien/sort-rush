# Agent handoff — Sort Rush

For any coding agent picking this up: Codex, Cursor, Claude Code, or a human doing an agent's job.

**This file is not the rules.** The rules are `CLAUDE.md` — the project constitution. Read it first; it overrides anything here. This file carries the things no other document records: environment quirks, hard-won testing knowledge, and where the work actually stands.

Keep this file current. If you finish a slice, update *Where things stand* before you sign off.

---

## The one thing most likely to go wrong

**This project is human-gated. Agents propose; they do not decide.**

There are `proposed` entries in `docs/decision-log.md` right now — level 5's pass condition, home's one-tap promise at large text scales, and backgrounding behaviour. Implementing a `proposed` decision because it looks sensible is the single worst thing you can do here — it converts a pending decision into a fait accompli and the log stops being trustworthy.

- Do not implement a `proposed` decision.
- Do not change a decision's status. Only the human does that.
- Do not start a milestone whose gate has not been approved. Milestone 4 is currently open; Gate 4 has not been reached.
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
flutter test         # 169 passing as of 2026-08-17
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

**`ResultsScreen` runs a `Timer.periodic`** — 40ms per line, eight lines, self-cancelling on the tick after the last. Pump ~500ms to let it finish, or tap to skip (which cancels it). Otherwise the test ends with a timer pending.

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

*Last updated 2026-08-16, first slice of Milestone 4.*

**Gate 3 passed. Milestone 3 is closed and Milestone 4 is in progress.** Home → shifts 1–9 → Results → Retry plays end to end. `flutter analyze` clean, 169 tests passing.

**Milestone 4 progress:** the pass condition is generalised (`lib/core/pass_condition.dart`) and level 4 ships. The required scenarios that needed no design ruling — small and large screens, text scaling, orientation — are now covered by `test/ui/responsive_test.dart`, which found and fixed a P1: home and the briefing overflowed at large text scales and pushed their primary buttons off-screen entirely. `lib/ui/widgets/fit_or_scroll.dart` is the fix. Levels 5–10 are blocked — see below.

**The most important thing to know about that ruling:** "no P0/P1 bugs" was accepted on automated testing alone. The app has never run on Android — there is no SDK here — so layer 5 of `docs/testing-strategy.md` has never executed, and the fairness floors in `docs/level-spec.md` rest on inferred reaction-time ranges rather than measurement. **The device test is Milestone 4's first obligation.** Do not treat those numbers as settled.

**Milestone 4 scope**, approved as a set at Gate 3 and specified in `docs/decision-log.md`:

- `DAMAGED` = a package that enters a visibly corrupted state, then re-renders as a different shape. The telegraph is the whole mechanic — a silent change punishes a decision already committed to. Never on the same package as `PRIORITY`, and the unstable state must not strobe.
- Double-or-nothing as an opt-in wager on the results screen. Not a stamp, because both modifier slots are spent.
- Onboarding levels 4–7 stay deterministic. No imposed RNG in the tutorial.
- Audio pipeline opens. Prompts are in `docs/audio-brief.md`. Two gates ride on it: Suno's commercial terms must be verified against the Play release, and `pubspec.yaml`'s no-asset-pipeline line must be amended rather than worked around.

**Levels 5–10 are each blocked, and the reasons differ:**

- **L5** — its approved pass condition ("reach combo x3") clears in ~21s, under the spec's own 30–90s band. Recorded as `proposed` in the decision log; needs a ruling. **Levels 6–10 sit behind it**, because shipping 6 without 5 leaves a gap that strands the player mid-ladder.
- **L7** — needs "clutch saves", which is design-spec §12.4 and was explicitly not ruled on at Gate 3.
- **L8, L9** — need compound shape+colour routing. No such `RoutingRule` exists.
- **L10** — needs the `PRIORITY` stamp. `PackageSpec` has no stamp field.

**Still open, not ruled on:** design-spec §12.4 (near-miss clutch bonus), §12.5 (level 1 having no failure state), §12.6 (results-screen design pass — M3-04 folds into it). Defects M3-02 to M3-04 are P3 and open.

**Nothing is committed** beyond the initial commit and a README update. All the test files, docs, screenshots, and the M3-01 fix are uncommitted working-tree changes.

---

## If you are asked to "improve" this project

The temptation is to add features. Resist it. In rough order of what actually helps:

1. **Get it onto an Android device.** Milestone 3 closed with its weakest criterion unproven and the fairness floors unmeasured. Everything else is guesswork until this happens.
2. **Coverage the gate names as missing** — backgrounding and relaunch, small and large screens, text scaling, orientation. All are required scenarios in `docs/testing-strategy.md` with no tests today. None needs a design decision, so this is the safest useful work available without asking anyone.
3. **Milestone 4's approved scope**, in `docs/decision-log.md`. Read the `DAMAGED` entry carefully before implementing it — the telegraph is the mechanic, not a nicety, and dropping it turns a skill into a coin flip.
4. **Never** add monetization. The constitution forbids it until repeat play is demonstrated by human testing.

Every task report must include: current state, goal, evidence, proposed action, files to change, tests to run, risks, explicit non-goals, approval status, and decision-log update. That list is from `CLAUDE.md` and it is not optional.

---

## Document map

| File | What it is |
|---|---|
| `CLAUDE.md` | The constitution. Mission, non-negotiables, milestones. Read first. |
| `docs/decision-log.md` | Every decision, its evidence, its gate status. The project's memory. |
| `docs/milestone-3-gate.md` | Gate 3, closed 2026-08-16: criteria, evidence, defects, and the rulings. |
| `docs/product-brief.md` | Pitch, target player, risks, scope ceiling, discarded alternatives. |
| `docs/design-system.md` | Visual direction, novelty budget, interaction and accessibility rules. |
| `docs/design-spec.md` | Screen-by-screen spec, Flutter/Flame mapping, open questions in §12. |
| `docs/level-spec.md` | Levels 1–10, endless curve, difficulty parameters, fairness floors. |
| `docs/backlog.md` | Captured intent that is not designed and not scheduled. Not approved, not buildable as written. |
| `docs/audio-brief.md` | Soundtrack direction and generation prompts. Production material, not a decision; the audio decision itself was approved at Gate 3. |
| `docs/testing-strategy.md` | Test layers, required scenarios, bug format, severity rubric. |
| `docs/screenshots/` | Web captures of every screen. Layout evidence, not device evidence. |
