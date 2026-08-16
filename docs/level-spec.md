# Level Specification

## Level principles

Teach one meaningful pressure at a time, then combine previously learned pressures. Avoid random difficulty spikes. Every failure should be explainable.

## Curated onboarding

| Level | Teaching objective | New pressure |
|---|---|---|
| 1 | Match one package type | One destination |
| 2 | Understand three bins | Three destinations |
| 3 | Recognize two package colors | Package variety |
| 4 | Recognize three package colors | Faster decisions |
| 5 | Understand combo scoring | Streak pressure |
| 6 | Manage two active packages | Queue pressure |
| 7 | Recover from a near miss | Timing pressure |
| 8 | Recognize shape plus color | Accessibility redundancy |
| 9 | Combine speed and queue pressure | Mixed pressure |
| 10 | Demonstrate mastery | Final onboarding challenge |

Each level should be 30–90 seconds and have a stated pass condition.

## Curated level parameters — proposed, awaiting gate

Teaching objectives above are unchanged. The numbers below are the proposed first pass, to be replaced by measured values after device testing.

`T` = read window in seconds (spawn to sort line). `S` = spawn interval in seconds. `A` = max active packages. `M` = mistake limit.

| L | Kinds available | T | S | A | M | Pass condition | Est. duration |
|---|---|---|---|---|---|---|---|
| 1 | 1 shape | 4.0 | 2.6 | 1 | — | 10 correct | ~30s |
| 2 | 3 shapes | 4.0 | 2.4 | 1 | 3 | 12 correct | ~33s |
| 3 | 3 shapes, 2 colors | 3.6 | 2.2 | 2 | 3 | 14 correct | ~35s |
| 4 | 3 shapes, 3 colors | 3.2 | 1.9 | 2 | 3 | 16 correct | ~34s |
| 5 | same as 4 | 3.0 | 1.8 | 2 | 3 | reach combo x3 | ~40s |
| 6 | same as 4 | 2.8 | 1.4 | 3 | 3 | 22 correct | ~34s |
| 7 | same as 4 | 2.4 | 1.4 | 3 | 3 | 20 correct incl. 2 clutch saves | ~30s |
| 8 | compound shape+color | 2.6 | 1.5 | 3 | 3 | 18 correct, ≤1 misroute | ~30s |
| 9 | compound | 2.2 | 1.1 | 4 | 3 | 28 correct | ~33s |
| 10 | compound + `PRIORITY` stamp | 2.0 | 0.95 | 4 | 3 | 30 correct, reach combo x4 | ~31s |

Level 1 has no mistake limit by design: the first level must be impossible to fail. A player who fails within 30 seconds of first launch does not open the game again.

Level 10's `PRIORITY` stamp was a deviation from this document's original scope, **approved at the 2026-08-16 human gate**. Its purpose is to prevent endless mode from introducing the override mechanic as a cliff.

Combo is active and displayed from Level 1. Level 5 teaches the player to chase it; it does not switch it on.

Build order: levels 1–3 are the Milestone 3 prototype. Levels 4–10 and endless are Milestone 4.

### Intended feeling and likely failure point

| L | Intended feeling | Likely failure point |
|---|---|---|
| 1 | "Oh, that's it." | none — should be unfailable |
| 2 | Orientation | mis-tapping an adjacent bin |
| 3 | First real reading | reading shape when color now matters |
| 4 | Mild pressure | hesitation between three colors |
| 5 | Greed | breaking a streak by rushing |
| 6 | Crowding | eyes on the queue instead of the active package |
| 7 | Relief | panic-tapping as the sort line turns `warn` |
| 8 | Concentration | reading one attribute and ignoring the other |
| 9 | Flow or flood | queue outruns decision speed |
| 10 | Competence | the stamp override on a reflex answer |

## Endless parameters

Store spawn interval, package speed, maximum active packages, mistake limit, available package kinds, and ambiguity rules in data/configuration rather than scattered constants. Use a fixed seed in automated tests.

### Endless curve — proposed, awaiting gate

Pressure index `P` increments by 1 per correct sort. `P` never decreases; failure ends the run rather than easing it, so the curve stays legible.

- `S(P) = max(0.65, 2.4 - 0.020 * P)` — floor reached at `P = 87`
- `T(P) = max(1.20, 4.0 - 0.030 * P)` — floor reached at `P = 93`
- `A(P) = min(5, 1 + floor(P / 18))`
- `M = 3`, fixed for the whole run

Kind unlocks: `P=0` 3 shapes, 1 color · `P=12` 2 colors · `P=28` 3 colors · `P=45` compound shape+color · `P=65` `PRIORITY` stamp · `P=90` `DAMAGED` stamp.

Reaching maximum pressure takes roughly 130 seconds of clean play. A strong run should last 2–4 minutes.

**The floors are the fairness contract.** `T` floors at 1.20s because a first-time player needs roughly 400–600ms for a three-way choice and another 200–350ms to resolve an override, and the read window must exceed that with margin. `S` floors at 0.65s because sustained throughput below that outruns decision speed regardless of skill. Neither floor may be lowered without device-test evidence, and difficulty must escalate by compressing `S` toward its floor before compressing `T` — taking away the read window is what makes a game feel unfair, while taking away recovery time is what makes it feel fast.

## Tuning record

For each change record: build, level/seed, observed failure point, intended feeling, changed parameter, and reason.

## Tuning record

For each change record: build, level/seed, observed failure point, intended feeling, changed parameter, and reason.
