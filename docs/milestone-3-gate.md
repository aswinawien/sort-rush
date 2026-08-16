# Milestone 3 — Prototype Gate

Status: **accepted at the human gate, 2026-08-16.** Milestone 3 is closed and Milestone 4 is open.

The criteria below were accepted as written, **including the explicit gap that "no P0/P1 bugs" rests on automated testing alone.** That gap was not waved away; it was accepted with the record stating it, and it carries forward as Milestone 4's first obligation. Nothing here has been retroactively upgraded to look better after the ruling.

Prepared 2026-08-16 at 89 passing tests. Updated after the gate at 91, with M3-01 fixed under it.

## Acceptance criteria

Criteria are taken verbatim from `CLAUDE.md`: *"Prototype: one complete run, scoring, combo, game over, restart, no P0/P1 bugs."*

| Criterion | State | Evidence |
|---|---|---|
| One complete run | Evidenced | `test/scenarios/complete_run_test.dart` → *a first-launch player can complete a whole shift and see it reported*. Drives Home → `PUNCH IN` → briefing → `START BELT` → ten sorts through Flame's real tap pipeline → pass → Results, in one test with no engine shortcuts. |
| Scoring | Evidenced | Same test asserts a final score of 170 end to end, and that Results prints `SCORE         170`. Rules covered by `test/core/score_state_test.dart` (8 tests). |
| Combo | Evidenced | Same run crosses two tiers and Results prints `BEST COMBO    x3`. Tier arithmetic and combo breaks covered in `test/core/score_state_test.dart`. |
| Game over | Evidenced | Two independent paths. Misroutes: *running out of mistakes ends the shift and says so* — three wrong chutes on shift 2 → `SHIFT ENDED`. Drops: *a dropped package is a mistake, and enough of them end the shift* — never tapping → three drops → `SHIFT ENDED`. |
| Restart | Evidenced | `test/scenarios/complete_run_test.dart` → *the player can restart from results and play again*. `CLOCK BACK IN` returns to the briefing and the second run starts at score 0 with a fresh package, so it is a new run rather than the old one redisplayed. |
| No P0/P1 bugs | **Not established** | 89 automated tests surface no P0 or P1. That is not the same as the criterion being met: layer 5 of `docs/testing-strategy.md` (human device test) has never run, and no build has executed on an Android device. One P2 is open — see below. |

## Test coverage added for this gate

63 tests before, 89 at the time of the ruling, 91 after M3-01 was fixed under the gate. The gap was never in the rules; it was that nothing exercised the screens that actually deliver the criteria.

| File | Tests | What it closes |
|---|---|---|
| `test/ui/play_screen_test.dart` | 9 | The briefing gate, pause holding the belt, input being refused while held, resume, quitting from the scrim, and both directions of the M3-01 back-gesture fix. Pause/resume is a required scenario that had no coverage. |
| `test/ui/results_screen_test.dart` | 12 | Pass vs fail copy, verdict stamps, progression gating, skippable printing, and all three exits. This screen carries the restart criterion and had no coverage. |
| `test/scenarios/complete_run_test.dart` | 4 | Layer 4 of the testing strategy, which had no tests at all. Full runs driven through the real widget tree. |
| `test/game/sort_rush_game_test.dart` | +3 | Chute boundaries: both outer edges of a chute are live, and a tap in the gap costs the player nothing. |

## Required scenarios

From `docs/testing-strategy.md`. Honest status, not aspirational.

| Scenario | Status |
|---|---|
| First launch | Covered — scenario tests enter from `HomeScreen` |
| Correct sort / wrong sort | Covered |
| Combo increase / break | Covered |
| Maximum mistakes | Covered — misroute path and drop path |
| Timeout | Covered — drop at the sort line |
| Pause / resume | Covered |
| Restart | Covered |
| Rapid taps | Covered — `test/core/run_engine_test.dart` |
| Bin boundaries | Covered |
| Fixed seed | Covered — `test/core/run_engine_test.dart` determinism group |
| Tutorial | Not applicable in the prototype — onboarding is Milestone 4 |
| Backgrounding / relaunch | **Not covered** |
| High-score persistence / unlock persistence | **Not applicable** — no persistence exists yet (Milestone 4) |
| Sound disabled | **Not applicable** — no audio exists yet |
| Small / large screens | **Not covered** — every test runs at the default 800×600 test view |
| Text scaling | **Not covered** |
| Orientation | **Not covered** |
| Malformed save data | **Not applicable** — nothing is saved yet |

## Visual evidence

In `docs/screenshots/`. Captured 2026-08-16 from the **web release build** in headless Chrome at 390×844 CSS pixels (2× density), driven by coordinate taps — Flutter web paints to a canvas, so there is no DOM to click.

**These are not device captures.** No Android SDK is installed on the development machine, so nothing has run on Android. Web rendering goes through CanvasKit: text metrics, touch behaviour, and frame pacing will differ from the real thing. Treat these as layout and typography evidence only. Milestone 4's device test is still the thing that decides fairness and feel.

| File | Shows |
|---|---|
| `01-home.png` | Misregistered title, one-tap `PUNCH IN`, the three shift rows |
| `02-briefing.png` | Shift 1 briefing, tutorial copy, and `NO PENALTY THIS SHIFT.` |
| `03-play.png` | Live belt: HUD score and combo, a package in transit, sort line, single chute with silhouette and letter |
| `04-pause.png` | `BELT HELD` scrim with `RESUME` and `QUIT TO HOME` |
| `05-results.png` | A genuine passing run — `SORTED 10 / MISROUTED 0 / DROPPED 0 / BEST COMBO x3 / SCORE 170`, `CLEARED` stamp, all three exits |
| `06-results-failed.png` | Shift 2 failed on three drops — `SHIFT ENDED`, `PROBATIONARY`, no `NEXT SHIFT` |
| `07-play-level-3.png` | Shift 3: hues paired with fill patterns, bins carrying colour-free pattern swatches, mistake pips in the HUD |

`05-results.png` is worth noting as independent confirmation: a run played in a real browser at real wall-clock speed, through real taps, produced exactly the score of 170 and best combo of x3 that `test/scenarios/complete_run_test.dart` asserts. The test and the running app agree.

`07-play-level-3.png` is the visual proof of the approved decision *Color is never load-bearing alone*: the cyan package is solid and the pink one is hatched, and both chutes identify themselves with a pattern swatch and a letter rather than a colour.

The grey fill on `HOME` in `06-results-failed.png` is a hover state left by the capture mouse, not a design choice.

## Open defects

| ID | Severity | Summary |
|---|---|---|
| M3-01 | P2 | **Fixed at this gate.** Android system back during a live run popped straight to Home, discarding the run with no pause and no confirmation. `PlayScreen` now wraps its Scaffold in a `PopScope`: a running belt swallows back and holds instead, a held belt lets it through. Two tests in `test/ui/play_screen_test.dart` cover both directions. |
| M3-02 | P3 | While paused, the pause/resume icon still draws in the top-right corner but the scrim swallows taps on it, so it reads as a live control that does nothing. `RESUME` in the scrim is the only working path. Confirmed by probe: tapping the icon's position while paused leaves the phase `paused`. |
| M3-03 | P3 | The pause scrim sits at 0.88 alpha, so the frozen belt shows through directly behind `RESUME` and `QUIT TO HOME`. Visible in `04-pause.png`, where a package sits behind the quit label and costs it contrast. |
| M3-04 | P3 | On a tall screen the results manifest leaves a large empty band between the verdict stamp and the buttons — see `05-results.png`. Content is top-aligned inside the scroll view and the actions are bottom-aligned. This is concrete input for open design question §12.6 rather than a bug to fix blind. |

No P0 or P1 defects are known. Per the completion rule in `docs/testing-strategy.md`, P2 and P3 do not block the milestone — but that is the gate's call, not the agent's.

One observation for the design pass, offered as a question rather than a defect: in `07-play-level-3.png` both chute swatches are drawn as squares, so a player arriving from shifts 1–2 — where a square silhouette meant "squares go here" — meets a square that now means "solid pattern". The level announces the switch in its briefing copy, and that may be enough. A static screenshot cannot settle it; a human test can.

## Gate outcome — ruled 2026-08-16

| Item | Ruling |
|---|---|
| Milestone 3 acceptance criteria | **Accepted**, with the "no P0/P1 bugs" device-test gap recorded rather than resolved. Milestone 3 closes; Milestone 4 opens. |
| M3-01 (P2, back destroys a run) | **Fix now.** Option (b) — `PopScope` holds the belt. Implemented and tested under this gate. |
| M3-02 to M3-04 (P3) | Left open. M3-04 folds into the §12.6 results-screen design pass. |
| Six decision-log entries predating the gate | **All ratified.** |
| Two entries raised while preparing the gate | **Both approved** — *System back during a live run*, *Prototype screenshots are web captures*. |
| Four Milestone 4 scope proposals | **Approved as a set** — `DAMAGED` telegraphed shape-shift, double-or-nothing wager, onboarding levels 4–7 stay deterministic, audio direction and asset pipeline. |
| Design-spec §12.4, §12.5, §12.6 | **Not ruled on. Still open.** |

Recorded in `docs/decision-log.md` under *Gate 3 outcome: Milestone 3 accepted*.

**What Milestone 4 inherits, unresolved:** the app has never run on Android hardware, so the fairness floors in `docs/level-spec.md` rest on inferred reaction-time ranges rather than measurement, and the "no P0/P1" claim rests on `flutter test` alone. Neither is settled by this gate. Both are Milestone 4's problem, and the device test is the first thing that should happen in it.

## What this gate was asked to decide

1. **Accept or reject the criteria evidence above**, including the explicit gap that "no P0/P1 bugs" rests on automated tests alone until a device test runs.
2. **M3-01 through M3-04** — for M3-01, take option (b) (back opens the pause scrim), leave it, or defer to Milestone 4. M3-02 to M3-04 are P3 polish; M3-04 should be folded into the §12.6 design pass rather than fixed on its own.
3. **Twelve decision-log entries marked `proposed`.** Six predate this gate: *Stack versions for prototype*, *Control model: tap-the-bin with front-most active package*, *Pure-Dart gameplay core with injected seeded RNG*, *Fairness floors for difficulty scaling*, *Presentation-layer deviations from design-spec §9*, and *Android target API level for the Play release*. Two came out of preparing it: *System back during a live run* and *Prototype screenshots are web captures, not device captures*.
4. **Open design questions in `docs/design-spec.md` §12** — 12.4 (near-miss clutch bonus, Milestone 4), 12.5 (level 1 having no failure state), and 12.6 (the results screen design pass; `SHIFT COMPLETE` / `SHIFT ENDED` is still the interim answer).
5. **The shape of Milestone 4.** Four proposals were raised from play testing on 2026-08-16 and are recorded in `docs/decision-log.md`: *`DAMAGED` defined as a telegraphed shape-shift*, *Double-or-nothing as a results-screen wager*, *Onboarding levels 4–7 stay deterministic*, and *Audio direction and asset pipeline*. They are deliberately answered as one set — together they fill the remaining rule-modifier slot, add the wager without touching the active loop, keep the onboarding curve as specified, and open the asset pipeline. Nothing in the set exceeds the scope ceiling. Deciding them piecemeal risks approving a mechanic whose slot another one has already spent.

## Explicit non-goals of this gate

No feature was added. No design was changed. No level parameter was touched. No decision-log entry was rewritten or re-statused. The work was evidence and one recorded defect.

## Reproducing

```bash
flutter analyze          # expect: No issues found!
flutter test             # expect: 91 passing (89 at the time of the ruling)
```

Neither has run on an Android device, and no release `appbundle` has been built — no Android SDK is installed on the development machine. Both remain open for Milestone 4.
