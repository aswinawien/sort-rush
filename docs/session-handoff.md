# Session handoff — 2026-08-22

State of the tree at the end of the visual/audio slice, written so another
agent or editor can pick it up without re-deriving anything.

## Verified state

```
dart format --output=none --set-exit-if-changed .   100 files, 0 changed
flutter analyze                                     No issues found
flutter test                                        412 passed, 0 failed
flutter build web --release                         builds clean
```

**Nothing is committed.** 77 paths are dirty, including whole new directories
(`assets/`, `lib/dev/`, `docs/screenshots/`). `git status` before anything else.

52 files in `lib/`, 46 test files.

## Environment

- Flutter 3.47.0 / Dart 3.13.0 at `/home/aswinawien/flutter/bin` — **not on
  PATH by default**. `export PATH=/home/aswinawien/flutter/bin:$PATH` first.
- **No Android SDK.** `flutter build appbundle` cannot run here, and no
  measurement in this repo has ever touched a real GPU.
- Playtest build served at `http://localhost:8090` (from `build/web`).
- Recording tooling: `/tmp/ffmpeg-7.0.2-amd64-static/ffmpeg`, CDP screencast
  driver `/tmp/rec9.js`, tap/console probe `/tmp/repro2.js`. Node 24 has a
  global `WebSocket`; no `ws` package needed.

## What shipped today

| Area | State |
|---|---|
| `DAMAGED` telegraph | Recoloured off `Tokens.warn` — package-hue ghost, `mute` tears, active outline preserved. Guard test asserts zero warn-family pixels. |
| Post-sort collapse burst | `lib/game/effects/chip_burst.dart`. Neon adds wake, flash, paper fragments. Bars only, deterministic, bounded, reduce-motion off. |
| Chute press feedback | Compression + two `mute` registration marks on tap-down, ~110ms decay. Fires on empty-belt no-ops. Never `acid`. |
| Visual style | `VisualStyle.standard` / `.immersiveNeon`, persisted, Options screen, in-game Reduce Motion that **OR**s with the platform preference. |
| Memo variants | Six, one shared `MemoTransition`, wired into the real `MemoBoard` via a `variant` param. Timing bands clamped and tested. |
| Music | 10 of 14 OGG tracks. Tempo-band fallback for the missing four. Endless crossfade driven from the game loop. One mute governs music + SFX. |
| Zine pass | `Halftone` on paper surfaces, `ScanLines` stays on `ink`. Serial stamps derived from real run values. |
| Dev tooling | `lib/dev/` — Dev Lab (F3–F10), profiler, effect counters. `kDevTools = !kReleaseMode`. Documented in `docs/qa-visual-workflow.md`. |

Two QA passes ran. Round one found and fixed 1 P1, 4 P2s and 3 P3s — see the
decision log entries dated 2026-08-22.

## Open decisions — these need a human, not an agent

1. **Acceptance criterion 8 is violated.** `RunEngine.update` returns early
   unless the phase is `running`; `buy`/`skipShop` flip it back to `running`
   on the tap, while `PlayScreen._shopOpen` stays true through the exit
   animation. So the engine runs with input blocked for ~176ms (Standard),
   ~240ms (Neon), 0ms (Reduce Motion). That advances `_elapsed`, which drives
   the endless board-swap schedule — and the spawn timer, so a package can
   appear *behind the covering overlay*. **A presentation setting is changing
   gameplay timing.** Recommended fix: pause the engine on shop open and
   resume in `_closeShop`, so all three modes are identical. Not applied.
2. **Is "which bin?" permanently the core skill?** The rhythm inquiry hinges
   entirely on this. If yes, beat-driven spawning is closed for good — it is
   also arithmetically impossible against the endless curve, see below.
3. **Gate 4** remains open. `docs/milestone-4-gate.md` recommends hold. Music
   now exists, so the "explicit music deferral" option is gone; what remains
   is a human device session that fills the questionnaire and times the
   1.20s / 0.65s floors.

## Known issues, not fixed

- **Neon collapse wake reaches ~24px above the chute lip.** Currently
  unreachable — a package needs `progress > 0.90` to enter that band, and the
  0.65s spawn floor keeps the following package further back. Guaranteed by an
  unrelated constant, not by the effect geometry. Shorten the spawn gap and
  this needs redoing.
- **Missing audio**: `l07`, `l08`, `l10`, `results.ogg`. The first three fall
  back within their tempo band (7,8→`l06`; 10→`l09`). `results.ogg` has no
  fallback and the results screen is silent. Dropping the files in needs no
  code change — filenames are lowercase-L, e.g. `l07.ogg`, **not** `107.ogg`.
- **Immersive Neon is unmeasured** and stays default-off until real-device QA.
- **Web renders `monospace` as a proportional sans.** All footage and
  screenshots under-represent the intended type. Android resolves a real mono.

## Traps that cost time today

Worth knowing before editing.

- **String-replace edits failed silently four times.** Twice the target text
  had been reformatted by `dart format`; once a constant had changed
  (`dt * 6` → `dt * 3`). Each failure compiled and every test still passed.
  The analyzer caught one (`unused_element_parameter`); the others were only
  caught by a QA pass. **Assert your replacements applied.**
- **A green suite is not a green build.** Three real bugs shipped with 405+
  tests passing: a `LateInitializationError` that only reproduced in a browser
  because the tester's `pump()` let Flame's async `onLoad` finish; a
  `setState()`-during-build throw that the covering test missed because it
  passed a benign callback instead of one that behaves like production; and a
  chute press that never decayed because its test only asserted nothing threw.
  **Reproduce runtime bugs in a real browser via CDP console capture.**
- **`pkill -f <pattern>` kills your own shell** when the pattern appears in
  your command line. Cost three sessions. Use `pkill chrome` (name match).
- **`rootBundle` reads never complete under the test binding.** Asset
  discovery is injectable (`AudioController(tracks: ...)`) for that reason.
- **Flutter no longer emits `AssetManifest.json`.** Reading that filename
  finds nothing and plays no music, silently. Use
  `AssetManifest.loadFromAssetBundle`.
- **The results screen never settles** (the cursor blinks forever). Use
  `pump(Duration(seconds: 8))`, not `pumpAndSettle`.

## Design constraints that are load-bearing

Do not relax these without reopening the decision that set them.

- Package identity is **shape + fill pattern**. Colour is never the only
  channel; the game must stay playable with all three hues rendered grey.
- `warn` means "you lost something". It is not available for damage,
  acknowledgement, or emphasis.
- **Nothing decorates a package while it is still routable.** No trails, no
  halos, no target rings. Effects fire after the package leaves the belt.
- The belt is `ink`. The **wall** may carry stepped scan lines; packages and
  chutes may not. Paper surfaces get halftone, never scan lines.
- Depot memo copy is exact: `DEPOT MEMO` / `PIN ONE. OR WALK ON.` / `PAY N` /
  `COST N` / `ASK AGAIN` / `WALK ON`. Never `SHOP`, `STORE`, `BUY`, `REROLL`.
- Fairness floors: read window **1.20s**, spawn interval **0.65s**. Beat-grid
  spawning is arithmetically impossible against the endless curve — at 104 BPM
  there is no legal beat multiple inside the 1.10s→0.65s range.
- Sound-off play must remain fully viable. Music is atmosphere, never a cue.
- Scope ceiling: 3 runtime dependencies, already full (`flame`,
  `shared_preferences`, `audioplayers`). A fourth is a ceiling breach.

## Commands

```
export PATH=/home/aswinawien/flutter/bin:$PATH
flutter pub get
dart format .
flutter analyze
flutter test
flutter build web --release            # playtest bundle
flutter run -t lib/dev/dev_lab.dart -d chrome   # profiler + memo preview
flutter build web -t lib/dev/dev_autoplay.dart --profile  # scripted capture
```
