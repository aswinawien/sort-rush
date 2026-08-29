# Milestone 4 — Vertical Slice Gate

Status: **awaiting the human gate, 2026-08-17.** Milestone 4 is not closed. Nothing in this packet upgrades a gap into a pass.

Prepared 2026-08-17 at 252 passing tests and a clean analyzer. Updated the same day after the presentation slice: **265** passing. Updated again after persistence: local `FLOOR RECORD` via `ScoreStore` + `shared_preferences`. The work is evidence. The ruling is yours.

## Acceptance criteria

Criteria are taken verbatim from `CLAUDE.md`: *"Vertical slice: onboarding, endless mode, persistence, feedback, device test."*

| Criterion | State | Evidence |
|---|---|---|
| Onboarding | Evidenced | Ten curated shifts ship (`kCuratedLevels`, asserted against `docs/level-spec.md` by `test/core/levels_test.dart`). Home lists all ten. `NEXT SHIFT` walks a clear forward. Level 10 (`RUSH JOB`) teaches `PRIORITY` so endless is not a cliff. Briefings carry the teaching copy. Layer 4 still drives a *first* shift end-to-end (`test/scenarios/complete_run_test.dart`), not a 1→10 chain. |
| Endless mode | Evidenced | Home offers `NIGHT SHIFT` with today's UTC stamp. `test/scenarios/endless_run_test.dart` enters the way a player enters, tightens the belt, and ends without ever being passed. Grow / swap, shop, `PRIORITY` at `P=65`, and the daily seed are covered in core tests. The memo-board overlay itself has no Flutter widget test — shop coverage is `test/core/shop_test.dart`. |
| Persistence | Evidenced | Local top-five endless board on Home (`FLOOR RECORD`). `ScoreStore` lives in `lib/core`; `shared_preferences` is behind `PrefsScoreStore`. Malformed JSON loads empty. Curated shifts are not stored. Unlock-gating endless is still undecided and unbuilt. Not a global leaderboard. |
| Feedback | **Partial** | Visual feedback ships. Gameplay SFX ship (synthesised ticks; mute on Home). Music files are not in the tree yet — generator is Gemini/Lyria, terms recorded 2026-08-17. Design-spec §11.3's sound half is met for misroute vs miss. |
| Device test | **Not established** | Emulator smoke on 2026-08-17 found three P1s (HUD under the status bar, identical compound chutes, invisible `DAMAGED` telegraph). All three were fixed the same day; D-01 was re-verified on `emulator-5554`. One developer web play on 2026-08-17: "looks good," no P0/P1 named. The questionnaire in `docs/testing-strategy.md` was not filled. The 1.20s / 0.65s floors have never been timed on a real player. §11.13's 60fps target has never been measured on a device GPU. |

A side criterion from an approved decision, not in the `CLAUDE.md` list: *"verify a release `appbundle` builds before Milestone 4 closes."* **Evidenced.** `flutter build appbundle --release` succeeded 2026-08-17 on Windows, 45.2 MB bundle, ~7 MB per arm64 device. That is not a substitute for the five criteria above.

## Recommendation

**Hold the gate.** Option (a) below.

Gate 3 accepted one gap of six criteria ("no P0/P1" on automated tests alone). Persistence now ships as a local floor record. Accepting this packet would still close onboarding / endless / persistence, wave feedback as partial (no audio), and record the device test as missing. That remaining gap is the questionnaire and the timed floors, not a missing store.

This is the gate's call, not the agent's.

## Options

| | Option | What it does |
|---|---|---|
| **(a)** | **Hold.** Recommended. | Milestone 4 stays open. Persistence and SFX have shipped. Remaining: Gemini loops dropped in (or an explicit music deferral), then a device session that fills the questionnaire and times 1.20s / 0.65s. |
| (b) | Accept with gaps recorded | Gate 3's pattern. Closes M4, opens M5, and writes persistence / audio / measured floors as inherited debt. Do this only if you are willing to put persistence into M5 by a new decision — M5 as written does not contain it. |
| (c) | Narrow the words | Treat "feedback" as visual-only, "device test" as emulator smoke plus "looks good," and persistence as a later slice. This rewrites `CLAUDE.md` without saying so. Rejected as an agent move. You can still choose it; it needs a new constitution line, not a silent close. |

## What shipped in this milestone

Against the Gate 3 inheritance (levels 1–3, no Android, no AAB):

- Curated ladder 4–10, including clutch saves, compound routing, `DAMAGED` as a telegraphed morph, `PRIORITY` as a compound Stroop, level 10 as the override teacher.
- Endless: two-phase curve, 2→3→4 chutes, lane swaps, `P` bar, UTC daily seed, memo-board shop at blinds 22 / 50 / 80, `PRIORITY` unlock at `P=65`.
- Double-or-nothing on a curated clear.
- D-01, D-02, D-03 found by looking, all fixed.
- Backgrounding holds the belt (`WidgetsBindingObserver` + three widget tests).
- Release AAB verified.
- One human play, qualitative.
- Local `FLOOR RECORD`: top-five endless scores via `ScoreStore` + `shared_preferences`. DEV strip is web-debug only.

## Test evidence for this gate

`flutter analyze` — No issues found (2026-08-17).
`flutter test` — **295 passing** after the floor-record slice (was 252 when this packet was first filed).

Layer 4 (the place acceptance-criteria evidence belongs):

| File | What it closes |
|---|---|
| `test/scenarios/complete_run_test.dart` | First-launch complete shift, scoring, combo, restart, misroute game-over, drop game-over. Still a *shift 1* run. |
| `test/scenarios/endless_run_test.dart` | Home → endless briefing → belt tightens → fail-only ending → no `NEXT SHIFT`, no `PROBATIONARY`. |

Supporting coverage added during M4, not a complete inventory: `levels_test` (ladder vs spec, fairness floors, duration band), `layout_change_test` (grow / swap / telegraph), `shop_test`, `priority_test` + `priority_stamp_test`, `play_screen_test` (background hold), `responsive_test` (text scale / small screens / landscape overflow), `bin_identity_test`, `corrupted_package_test`.

Known coverage holes that matter at this gate:

- No Flutter test for the memo-board overlay (buy / skip / unaffordable).
- No 1→10 `NEXT SHIFT` chain through the widget tree.
- No sound-disabled test — mute exists; a device session still has to confirm the game is fully playable with SOUND OFF.
- No killed-process relaunch of an in-progress belt. Scores now survive a fresh store.

## Required scenarios

From `docs/testing-strategy.md`. Honest status.

| Scenario | Status |
|---|---|
| First launch | Covered |
| Tutorial | Covered — briefing copy per shift; skip-tutorial is unbuilt Settings |
| Correct sort / wrong sort | Covered |
| Combo increase / break | Covered |
| Maximum mistakes | Covered — misroute path and drop path; endless fail-only path |
| Timeout | Covered — drop at the sort line |
| Pause / resume | Covered |
| Restart | Covered |
| Backgrounding | Covered — holds the belt; resume is deliberate |
| Rapid taps | Covered |
| Bin boundaries | Covered |
| Fixed seed | Covered |
| Small / large screens / text scaling | Covered for overflow; not a visual QA pass |
| Orientation | Layout does not overflow in landscape tests; portrait lock on a device is untested |
| Relaunch | Partial — scores restore from prefs; an in-progress belt does not |
| High-score persistence | Covered — local endless top five; curated shifts are not stored |
| Unlock persistence | **Not applicable** — unlocks are undecided and unbuilt |
| Sound disabled | Covered in widget tests (mute no-ops the bus). Device confirmation still open |
| Malformed save data | Covered — corrupt JSON loads as an empty board |

## Visual evidence

Web captures in `docs/screenshots/` are still the Milestone 3 set (home through level 3). They are layout evidence, not device evidence, and they predate levels 4–10, endless, the shop, and the wager.

Device captures in `docs/screenshots/device/`, from `emulator-5554` on 2026-08-17:

| File | Shows |
|---|---|
| `01-home.png` | Home on Android |
| `02-briefing.png` | Briefing on Android |
| `03-play.png` | D-01 as found — HUD under the status bar |
| `04-play-level5.png` | D-01 worse on level 5 — mistake pips on the signal icons |
| `05-play-fixed.png` | D-01 after immersive + HUD inset |

There is no device capture of compound chutes after D-02, of a `DAMAGED` telegraph after D-03, of level 10, of a lane swap, of the memo board, or of results. The human play on 2026-08-17 was web.

## Playtests

| Date | Who | Surface | Verdict | Questionnaire | Floors timed |
|---|---|---|---|---|---|
| 2026-08-17 | Developer | Web, 390×844 | "Looks good." No P0/P1 named. | Unanswered | No |
| 2026-08-17 | — | Android emulator | Smoke. Found D-01 (P1). D-02 and D-03 found by inspection the same day. | — | No |

Zero first-time-player sessions. Repeat play has not been demonstrated. `CLAUDE.md` still forbids monetization until that happens; that ban is untouched.

## Open defects

| ID | Severity | Summary |
|---|---|---|
| M3-02 | P3 | Pause icon still draws while the scrim swallows its taps. `RESUME` in the scrim is the working path. Left open at Gate 3. |
| M3-03 | P3 | Pause scrim at 0.88 alpha; frozen belt shows through the labels. Left open at Gate 3. |
| M3-04 | P3 | Tall-screen empty band on results. Folded into §12.6. Left open at Gate 3. |

No known P0 or P1. D-01, D-02, and D-03 were P1s found by looking; all three are fixed and guarded. Per `docs/testing-strategy.md`, P3 does not block a milestone — but a close that ignores the three missing criteria would.

## Residuals inside approved entries (still `proposed`)

These are not standalone log entries. Implementing one because it looks sensible converts a pending call into a fait accompli.

1. **Home's one-tap promise at 2× text.** At 2.0× on a 320px phone, `PUNCH IN` sits below the fold. Scroll-then-tap is strictly better than unreachable. Reorder vs. cap vs. live with it: not decided.
2. **Level 8 asks for 19, not the 18 in the spec**, so the duration band holds. Spec vs. data: not decided.
3. **Level 8's "≤1 misroute" is not implemented.** Immediate fail vs. play-on-knowing-you-cannot-win: not decided.

## Design-spec §12

| Item | State at this gate |
|---|---|
| §12.4 Near-miss clutch bonus | **Answered in practice** by *Clutch saves defined* (flat +5, `ClutchTarget(2)` on level 7). The spec section itself was never re-stamped. |
| §12.5 Level 1 failure state | **Still open.** Level 1 remains unfailable. Gate 3 left this unruled. |
| §12.6 Results design pass | **Still open.** `SHIFT COMPLETE` / `SHIFT ENDED`, the wager button, and M3-04 all sit on the interim layout. |

## Budgeted and unbuilt, not criteria

These do not appear in the `CLAUDE.md` Milestone 4 sentence. They are recorded so a close does not pretend they shipped.

- **Settings.** Fourth budgeted screen. Unbuilt. Mute, skip-tutorial, and jump-to-endless live here if they live anywhere.
- **Audio.** SFX shipped. Music waits on Gemini files in `assets/audio/`. Terms recorded. Mute is on Home; Settings stays unbuilt.
- **Quota contracts, hazardous cargo, scanner reveal.** Designed-not-built. Each needs its own entry before code.
- **Endless unlock after onboarding.** Specified in the product brief, undecided in the log, currently ungated on home.

## What this gate is asked to decide

1. **Accept, hold, or narrow** the five criteria above. The recommendation is hold.
2. **If hold:** remaining order is Gemini loops (or an explicit music deferral), then a device session that fills the questionnaire and times the floors. Persistence and SFX have shipped.
3. **The three residuals** (home at 2×, level 8 count, level 8 misroute cap). Rule, defer, or leave as residuals.
4. **§12.5 and §12.6.** Rule, defer to a design pass, or leave open.
5. **Settings.** Stay unbuilt through M4, or ride with audio mute / skip-tutorial.
6. **Designed-not-built mechanics** (quota, hazardous, scanner). Confirm they do not block this milestone.

## Explicit non-goals of this gate

As first filed, this packet added no feature. Persistence has since shipped as a local floor record; that does not close the gate. Audio and Settings were not started. Unlock-gating endless was not invented.

## Reproducing

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter analyze          # expect: No issues found!
flutter test             # expect: 295 passing
```

Android release (Windows side, not WSL):

```bash
powershell.exe -NoProfile -Command "cd 'E:\Game Dev\sort-rush'; & 'E:\flutter-sdk\flutter\bin\flutter.bat' build appbundle --release"
```

Verified 2026-08-17. Not re-run for this packet.
