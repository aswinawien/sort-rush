# Design Spec — Milestone 2 proposal

Status: **proposed, awaiting human gate.** Nothing here is approved. Implementation is Milestone 3 and is separately gated.

This document turns `docs/product-brief.md` and `docs/design-system.md` into an implementation-ready specification. Changes it makes to gameplay rules already stated in `docs/level-spec.md` are recorded in §12, along with the decisions still open.

---

## 1. The depth problem, stated plainly

Risk 1 in the product brief is that sorting feels like a tapping demo. That risk is real and it is not solved by speed. If a package reads "circle" and one bin reads "circle", the player is running a reflex test with no decision in it, and faster reflex tests do not become deeper — they become noisier.

Depth in this game comes from **attribute precedence**: the player must read more than one property of a package and apply a rule about which property wins. This is cheap to build (procedural shapes and mono type), it is teachable one step at a time, and it produces the specific feeling of a competent worker under pressure rather than a person mashing a button.

The escalation ladder, in order:

1. **Identity** — one attribute maps to one bin. (Levels 1–2)
2. **Attribute switch** — a different attribute now drives the mapping. (Levels 3–4)
3. **Compound** — two attributes together determine the bin. (Level 8)
4. **Override** — a stamp outranks the base rule, so the obvious answer is wrong. (Endless, previewed at Level 10)

Step 4 is where the game stops being a reaction test. A package shaped for Bin A but stamped `PRIORITY` goes to Bin B, and the reflex answer is a misroute. This is a deliberate Stroop-style conflict and it is the single most important mechanic in the design.

---

## 2. Control model

**Selected: tap-the-bin, front-most package is active.**

- Packages travel down a single belt toward a sort line above the bins.
- The front-most unsorted package is the **active** package and is visually marked. Only it can be routed.
- Tapping a bin routes the active package there. Bins are large, fixed, bottom-anchored, thumb-reachable.
- Packages behind the active one are visible as lookahead, so the player plans ahead and builds rhythm.
- If the active package crosses the sort line unsorted, it is a **miss**.

This keeps targets large and forgiving (design-system requirement) and removes any ambiguity about which package a tap applies to. Depth comes from rule precedence and rhythm, not from target selection.

### Alternative considered: free selection

Any visible package can be routed by tapping its bin while it is highlighted by proximity. Adds triage strategy — the player chooses sort order.

| Criterion | Front-most (selected) | Free selection |
|---|---|---|
| Comprehension | High — one rule, always true | Medium — "which one did I just sort?" |
| Touch safety | High — 3 fixed large targets | Medium — target meaning changes per frame |
| Distinctiveness | Medium | High |
| Implementation cost | Low | Medium |
| Failure risk | Low | High — ambiguous feedback on error |

Chosen on clarity, per the design-system rule that unusual core controls are not acceptable. Free selection is a reversible post-prototype experiment, not a v1 commitment.

---

## 3. Screen and state map

```
Boot
 └─> Home ──> Play (curated level N)  ──> Results ──> Home
      │         ↕ Paused                      └─> Retry ──> Play
      ├─> Play (endless) ──> Results ──> Home
      └─> Settings ──> Home
```

Play-state machine, owned by Flame:

```
ready ──start──> running ──pause──> paused ──resume──> running
                    │                  └──quit──> results
                    ├──mistakes == limit──> ending ──> results
                    └──pass condition met──> ending ──> results
```

`ending` is a distinct ~900ms state, not an instant cut: the belt halts, the final package settles, and the score locks. Instant transitions on failure read as a crash and rob the player of the "what just happened" beat.

**Milestone 3 (prototype) requires only:** Home → Play (curated levels 1–3) → Results → Retry. Endless, levels 4–10, Settings, and persistence are Milestone 4.

Note on combo: Milestone 3's acceptance criteria require combo to work, but combo is not *taught* until Level 5. These are reconciled by having the combo system **active and displayed from Level 1**, with Level 5's job being to make the player deliberately chase it rather than to switch it on. Levels 1–3 therefore exercise the full scoring path even though they do not instruct on it.

---

## 4. Design tokens

| Token | Value | Use |
|---|---|---|
| `ink` | `#0D0D0F` | Play field base |
| `paper` | `#F2EDE3` | Zine surfaces (Home, Results), bin outlines |
| `acid` | `#C6FF00` | Score, combo, active-package marker |
| `warn` | `#FF4B26` | Misroute, mistake pips, expiring package |
| `mute` | `#6E6E76` | Mono system labels, secondary copy |

Package hues, each **permanently paired with a fill pattern** so color is never load-bearing on its own:

| Kind | Hue | Pattern |
|---|---|---|
| 1 | `#38E1FF` | solid |
| 2 | `#FF4FD8` | diagonal hatch |
| 3 | `#FFC53D` | dotted |

Bins are outline-only silhouettes in `paper` on `ink`, differentiated by **shape + mono letter**, never by fill color. A player who cannot distinguish any of the three package hues can still play the entire game on shape and pattern alone.

Type: oversized display numerals for score and combo; compact mono for all system copy, labels, and stamps.

---

## 5. Screens

### 5.1 Home — 60% experimentation

- **Purpose:** start a run in one tap.
- **Player question:** "What is this and how do I start?"
- **Primary action:** `PUNCH IN` (starts endless, or next unfinished curated level).
- **Secondary:** `SHIFTS` (level select), `SETTINGS`, best score readout.
- **Treatment:** misregistered title with a 2px channel offset, faint scan lines, a slightly rotated sticker showing the best score, mono depot copy.
- **Copy:** title `SORT RUSH`; under it, `DEPOT 7 · NIGHT SHIFT`; best score as `BEST · 0`.

**Bold vs. safe:** the bold version animates the title's misregistration continuously; the safe fallback offsets it once, statically. Continuous motion behind a primary CTA is a comprehension risk and a battery cost. **Selected: safe fallback**, with the animated version fired once on entry only.

### 5.2 Play — 20% experimentation, 80% clarity

Layout, top to bottom:

1. **Status strip** — score (display numerals, `acid`), combo tier, mistake pips. Fixed height, never overlaps the belt.
2. **Belt** — packages descend. Occupies the vertical middle. This region gets no decorative treatment at all.
3. **Sort line** — a thin `mute` rule marking the deadline. Turns `warn` when the active package is within 0.4s of crossing.
4. **Bins** — three, bottom-anchored, full-width row.

- **Touch targets:** each bin ≥ 96dp tall and ≥ 30% of screen width, extending to the screen edge so edge taps register. No interactive element within 24dp of another.
- **Feedback at the point of action** (design-system requirement): correct sort collapses the package into the bin with an `acid` flash on the bin lip; misroute shakes the bin 6px and flashes `warn`. **Simultaneously** the score/combo region reacts — this dual-site feedback is required, not optional.
- **Motion:** correct 120ms ease-out; misroute 180ms with a single 1-frame RGB channel offset on the score readout only; combo tier-up briefly misregisters the combo numeral. That one-frame glitch on tier-up and error is the entire 20% experimentation budget for this screen. Nothing else on the play field glitches.
- **Copy:** on misroute, `MISROUTE` in `warn` mono. On miss, `DROPPED`. Never `WRONG`, never anything that blames the player.

### 5.3 Results — 60% experimentation

- **Treatment:** a dot-matrix **shipping manifest** that prints line by line (~40ms per line) on `paper`.
- **Copy:** header `SHIFT ENDED` — not `GAME OVER`. Lines: `SORTED`, `MISROUTED`, `DROPPED`, `BEST COMBO`, `SCORE`, and a rubber-stamp verdict.
- **Verdict stamps** by score band, stamped with slight rotation: `PROBATIONARY` / `CLEARED` / `EMPLOYEE OF THE SHIFT`.
- **Primary action:** `CLOCK BACK IN` (retry, same mode). **Secondary:** `HOME`.
- Printing animation is **skippable on tap** and fully skipped when reduce-motion is on. A player restarting for the fifth time must not be forced to watch it.

### 5.4 Settings — conventional and quiet

Sound toggle, haptics toggle, reduce-motion toggle, colorblind-friendly note, reset progress (with confirm). No treatment. Standard Material controls, system text scaling respected.

---

## 6. Audio and haptics

Every cue is redundant with a visual, so sound-off play loses nothing.

| Event | Sound | Haptic |
|---|---|---|
| Correct sort | short tick, pitch rises with combo tier | selection click |
| Combo tier-up | rising two-note stab | light impact |
| Misroute | dull thud | medium impact |
| Miss | descending tone | medium impact |
| Shift ended | belt spin-down | heavy impact |

Pitch rising with combo tier is the cheapest possible "you are doing well" signal and it works with the screen unwatched.

---

## 7. Accessibility

- Package identity is always shape + pattern; color is decorative reinforcement only.
- Bin identity is shape + mono letter; color is never the differentiator.
- Reduce-motion disables misregistration, scan lines, shake, and manifest printing. Gameplay timings are unchanged — reduce-motion must never alter difficulty.
- No flashing above 3Hz anywhere.
- System text scaling is respected on all Flutter-owned surfaces. The Flame canvas uses its own scale-aware layout and is exempt, per the constitution.
- Sound-off is a first-class mode, not a degraded one.

## 8. Responsive behavior

- Portrait only, locked.
- Layout is proportional: status strip 14% of height, belt 62%, bins 24%.
- Aspect ratios from 4:3 to 21:9 supported. On tall screens the belt absorbs the extra height, which increases the read window in pixels but **not in seconds** — travel time is time-based, never pixel-based. This is a hard requirement: pixel-based speed would make the game measurably easier on tall phones.
- Bins keep a fixed dp height and grow only in width.

---

## 9. Flutter / Flame mapping

Per the constitution: Flutter widgets own navigation, overlays, settings, and results; Flame owns the active loop.

| Element | Owner | Type |
|---|---|---|
| Home, Settings, Results | Flutter | `StatelessWidget` / `StatefulWidget` routes |
| Pause overlay, countdown | Flutter | Flame `overlays` |
| Game surface | Flame | `FlameGame` subclass, `SortRushGame` |
| Belt + spawning | Flame | `BeltComponent`, `SpawnerComponent` |
| Package | Flame | `PackageComponent` (shape, hue, pattern, stamp) |
| Bins | Flame | `BinComponent` × 3, `TapCallbacks` |
| Score/combo HUD | Flame | `HudComponent` — in-canvas so feedback is frame-synced with gameplay |
| Rules, scoring, difficulty | Pure Dart | no Flame or Flutter imports |
| Persistence | Flutter | `shared_preferences` behind a `ScoreStore` interface |

**The pure-Dart core is the load-bearing architectural decision.** Scoring, combo, difficulty curve, seeded RNG, and the play-state machine must have zero engine imports so they are testable without a game loop or a widget tree. This is what makes Testing Strategy layer 1 possible at all, and it is the main defense against the hidden-coupling risk in the product brief.

Randomness: a single seeded `Random` owned by the run, injected at construction. No `Random()` calls anywhere else. Same seed plus same input timeline must produce an identical run.

---

## 10. Component inventory

Pure Dart: `RunConfig`, `LevelConfig`, `DifficultyCurve`, `PackageSpec`, `RoutingRule`, `ScoreState`, `ComboState`, `RunState`, `SeededRng`, `ScoreStore` (interface).

Flame: `SortRushGame`, `BeltComponent`, `SpawnerComponent`, `PackageComponent`, `BinComponent`, `SortLineComponent`, `HudComponent`, `FeedbackBurst`.

Flutter: `HomeScreen`, `SettingsScreen`, `ResultsScreen`, `PauseOverlay`, `CountdownOverlay`, `ManifestPrinter`.

---

## 11. Acceptance criteria

Gameplay:
1. A first-time player completes a correct sort within 10 seconds of first launch without reading instructions.
2. Every correct sort produces feedback at both the bin and the score region within 1 frame of the tap.
3. A misroute is always distinguishable from a miss, by sound and by on-screen copy.
4. Tapping a bin with no active package on the belt is a no-op — never a mistake, never a score change.
5. Rapid multi-tapping a bin routes exactly one package per tap and never double-routes a single package.
6. Two runs with the same seed and the same input timeline produce identical score, combo, and mistake counts.

Presentation:
7. The play field contains no animated decoration during `running` except the specified one-frame glitches.
8. With reduce-motion on, all timings that affect difficulty are byte-identical to reduce-motion off.
9. Every package is identifiable with all three hues rendered as the same gray.
10. Every bin is ≥96dp tall and reachable one-thumb on a 5.0" device.

Technical:
11. `flutter analyze` reports zero issues.
12. Pure-Dart core has no `package:flame` or `package:flutter` import.
13. 60fps sustained with 5 active packages on a mid-range device.

---

## 12. Decisions

### Resolved at the 2026-08-16 gate

1. **[DEVIATION] Stamp override mechanic — approved.** Stamps are the endless depth escalation, and `PRIORITY` is previewed at Level 10 so endless is not a difficulty cliff. `docs/level-spec.md` is updated accordingly.
2. **Palette and color — approved as specified.** Bin identity is color-free (shape silhouette + mono letter); every package hue is permanently paired with a fill pattern. The game is fully playable in grayscale, so no separate colorblind mode is needed.
3. **Build order — levels 1–3 first, not endless.** The prototype ships curated levels 1–3; endless moves to Milestone 4. See §3 for how this is reconciled with Milestone 3's combo requirement.

### Still unresolved — need the human gate

4. **Near-miss "clutch" bonus.** Level 7 teaches near-miss recovery, which implies a rewarded save. This spec assumes a small bonus for sorting within 0.5s of the sort line. Confirm the bonus exists and whether it also protects the combo from breaking.
5. **Level 1 failure state.** Level 1 has no mistake limit by design, so it cannot demonstrate game-over. Milestone 3's game-over criterion is therefore exercised only by levels 2–3. Confirm this is acceptable rather than adding a mistake limit to Level 1.
6. **Results screen after a curated level.** The manifest metaphor was designed for an endless run's stats. For a curated level it must also communicate pass/fail and next-level progression. Needs a short follow-up design pass before implementation.
