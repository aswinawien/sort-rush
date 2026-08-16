# Decision Log

Record decisions as append-only entries.

## Template

### YYYY-MM-DD — Decision title

- Status: proposed | approved | rejected | superseded
- Context:
- Evidence:
- Options considered:
- Decision:
- Consequences:
- Owner/gate:

---

### 2026-08-16 — Stack versions for prototype

- Status: approved (human gate, 2026-08-16)
- Context: No code exists yet. The constitution fixes Dart/Flutter/Flame but not versions, and version choice affects both the prototype and the Play release.
- Evidence: Flutter stable is 3.47.0 per the official release-notes index. Flame's latest published version is 1.38.0, which requires Flutter ≥ 3.41.0 per its changelog (min bumped in 1.36.0). The two are therefore compatible. Sources cited in the Gate 1 report.
- Options considered: (a) pin Flame 1.38.0 on Flutter 3.47.0; (b) pin an older Flame for stability; (c) leave versions floating.
- Decision: Pin `flame: ^1.38.0` on Flutter 3.47.x, verified by `flutter pub get` and `flutter analyze` before any gameplay code is written.
- Consequences: Compatibility is confirmed at setup rather than discovered mid-prototype. Version bumps become explicit decisions.
- Owner/gate: human — Gate 2.
- Verified 2026-08-16: Flutter 3.47.0 / Dart 3.13.0 installed at `~/flutter`. `flutter pub get` resolved flame 1.38.0 with no conflicts. `flutter analyze` reports no issues; 63 tests pass. `flutter_lints` is pinned at 5.0.0 with 6.0.0 available — deliberately not bumped yet, since a lint major can introduce new findings that are unrelated to the milestone.

### 2026-08-16 — Attribute precedence as the depth mechanic

- Status: approved (human gate, 2026-08-16)
- Context: Product-brief risk 1 is that sorting feels like a tapping demo. Speed alone does not resolve it; a faster reflex test is still a reflex test.
- Evidence: The existing level table already escalates from single-attribute matching (L1–2) to compound shape+color (L8), so an attribute-precedence ladder is consistent with the approved teaching plan rather than a new direction.
- Options considered: (a) identity matching plus speed only; (b) attribute precedence ending in stamp overrides; (c) selection strategy via free-target routing.
- Decision: Adopt the four-step ladder — identity, attribute switch, compound, override — with stamps introduced in endless and previewed at Level 10.
- Consequences: Adds a `RoutingRule` abstraction and two stamp kinds. Level 10 gains a mechanic the original level spec did not list; flagged as a deviation requiring approval.
- Owner/gate: human — Gate 2.

### 2026-08-16 — Control model: tap-the-bin with front-most active package

- Status: approved (human gate, 2026-08-16)
- Context: The core control must be large, forgiving, one-thumb, and unambiguous about which package a tap affects.
- Evidence: Design system requires large forgiving destination controls and states that unusual core controls are not acceptable. Drag-based routing was scored worse on comprehension, touch safety, and failure risk.
- Options considered: (a) front-most active package, tap a bin; (b) free selection of any visible package; (c) drag package to bin.
- Decision: Option (a). Depth comes from rule precedence and rhythm, not target selection. Lookahead packages remain visible for planning.
- Consequences: Queue pressure is throughput pressure, not triage strategy. Free selection stays available as a reversible post-prototype experiment.
- Owner/gate: human — Gate 2.

### 2026-08-16 — Color is never load-bearing alone

- Status: approved (human gate, 2026-08-16)
- Context: The design system forbids communicating package identity by color alone, but levels 3–4 teach color recognition and three bins must be distinguishable. These pull against each other.
- Evidence: Direct contradiction between `docs/design-system.md` accessibility rules and `docs/level-spec.md` levels 3–4 and 8.
- Options considered: (a) drop color as a gameplay attribute; (b) pair every package hue with a fill pattern and make bin identity color-free; (c) accept color-only identity and rely on a colorblind mode toggle.
- Decision: Option (b). Bins are outline silhouettes plus a mono letter with no identifying fill color; each package hue is permanently paired with solid, hatch, or dotted fill.
- Consequences: The whole game is playable with all hues rendered as identical gray. Adds a pattern-render path to `PackageComponent`. The design-system "one accent, one warning" rule needs confirmation that decorative package hues do not violate it.
- Owner/gate: human — Gate 2.

### 2026-08-16 — Pure-Dart gameplay core with injected seeded RNG

- Status: approved (human gate, 2026-08-16)
- Context: Product-brief risk 4 is hidden coupling from AI-generated code. Testing-strategy layer 1 requires unit-testing scoring, combo, difficulty, seed replay, and state transitions without a game loop.
- Evidence: Those tests are only possible if the logic has no engine dependency; the constitution also requires seedable randomness and data-driven difficulty.
- Options considered: (a) logic inside Flame components; (b) pure-Dart core with Flame as a rendering and input shell.
- Decision: Option (b). Scoring, combo, difficulty curve, routing rules, seeded RNG, and the run state machine import neither `package:flame` nor `package:flutter`. One seeded `Random` is owned by the run and injected; no other `Random()` call exists.
- Consequences: A guard test asserts the core has no engine imports. Same seed plus same input timeline must reproduce a run exactly.
- Owner/gate: human — Gate 2.

### 2026-08-16 — Fairness floors for difficulty scaling

- Status: approved (human gate, 2026-08-16)
- Context: Product-brief risk 3 is that endless becomes unfair. Difficulty needs a stated limit rather than an open-ended ramp.
- Evidence: Three-alternative visual choice reaction time is roughly 400–600ms for untrained players, plus roughly 200–350ms to resolve an override rule. Inference from published reaction-time ranges, not measured on this game — device testing must confirm.
- Options considered: (a) unbounded ramp; (b) floor the read window and spawn interval; (c) adaptive difficulty tied to player performance.
- Decision: Option (b). Read window floors at 1.20s, spawn interval at 0.65s. Difficulty compresses spawn interval toward its floor before compressing the read window. Adaptive difficulty is rejected for v1 because it breaks seed determinism.
- Consequences: Endless has a maximum pressure that a skilled player can sustain, reached after roughly 130 seconds of clean play. Floors may only be lowered with device-test evidence.
- Owner/gate: human — Gate 2.

### 2026-08-16 — Prototype builds curated levels 1–3, not endless

- Status: approved (human gate, 2026-08-16)
- Context: Milestone 3 requires one complete run with scoring, combo, game over, and restart. The product brief unlocks endless only after onboarding, so the prototype had to either build endless out of order or build a curated slice first.
- Evidence: Building endless first reaches a full-pressure loop faster, but tests the mode a new player never sees first. Building levels 1–3 first tests the actual first-run experience, which is where the product brief's 30-second promise is won or lost.
- Options considered: (a) endless first, unlock gate added later; (b) curated levels 1–3 first; (c) both in the prototype.
- Decision: Option (b). The prototype ships Home → Levels 1–3 → Results → Retry. Endless and levels 4–10 move to Milestone 4.
- Consequences: Requires level progression and pass conditions earlier than planned. Combo must be active and displayed from Level 1 even though Level 5 teaches it, otherwise the prototype cannot satisfy Milestone 3's combo criterion. Level 1 has no mistake limit, so game-over is exercised only by levels 2–3. The Results screen must communicate pass/fail and progression, not just run stats — a follow-up design pass is open.
- Owner/gate: human — Gate 2.

### 2026-08-16 — Presentation-layer deviations from design-spec §9

- Status: approved (human gate, 2026-08-16)
- Context: Three implementation choices depart from the Flutter/Flame mapping table in `docs/design-spec.md` §9. Recording them rather than letting the code and the spec drift apart silently.
- Evidence: All three were made while implementing the Milestone 3 slice; the analyzer and 63 tests pass with them in place.
- Options considered: follow the mapping literally, or deviate and record.
- Decision: (a) `PackageComponent` is a painter called by `BeltComponent`, not one component per package — mirroring engine state into component lifecycles each frame adds a desync the player would see, for no visual gain. (b) Pause is a Flutter `Stack` rather than a Flame overlay, because pause must reach `Navigator` for "quit to home". (c) Results shows `SHIFT COMPLETE` on a pass and `SHIFT ENDED` on a fail; the manifest was specified for endless run stats and had no pass/fail concept.
- Consequences: §9's component inventory no longer matches the code exactly. (c) is an interim answer to open decision §12.6 and still needs a design pass.
- Owner/gate: human — Gate 3.

### 2026-08-16 — Android target API level for the Play release

- Status: approved (human gate, 2026-08-16)
- Context: Milestone 5 is a Google Play internal test. Target API configuration is cheap to set correctly at project creation and expensive to retrofit.
- Evidence: Google Play requires new apps and updates to target Android 16 (API 36) or higher from 31 August 2026, with extensions available to 1 November 2026. Existing apps must target API 35 or higher to stay available to new users on newer devices. Source: Play Console Help, "Target API level requirements for Google Play apps", retrieved 2026-08-16.
- Options considered: (a) set `targetSdk 36` at project creation; (b) accept the Flutter template default and fix before release.
- Decision: Set `compileSdk`/`targetSdk` to 36 when the Flutter project is created, and verify a release `appbundle` builds before Milestone 4 closes.
- Consequences: Removes a release-blocking surprise. May surface API-36 behavior changes early, which is the intent.
- Owner/gate: human — Gate 2.
- Verified 2026-08-16: no code change was needed. Flutter 3.47.0 already defaults `targetSdkVersion` to 36 (`FlutterExtension.kt:34`), and the generated `android/app/build.gradle.kts` reads `flutter.targetSdkVersion`, so the project already meets the 31 August 2026 requirement. Left on the Flutter default rather than hardcoded, so it tracks future SDK bumps; revisit if the default ever drops below the Play floor.
- Verified 2026-08-17: **`flutter build appbundle --release` succeeds.** Built against Android SDK 36.1.0 on the Windows side of this WSL machine, producing a valid 45.2MB bundle of 82 entries across `armeabi-v7a`, `arm64-v8a` and `x86_64`. Of that, 23.4MB is `BUNDLE-METADATA` debug symbols that Play consumes for crash symbolication rather than shipping, and 19.8MB is the app across all three ABIs — a single arm64 device downloads roughly 7MB. Milestone 5's release-blocking unknown is answered.

### 2026-08-16 — System back during a live run

- Status: approved (human gate, 2026-08-16)
- Context: `PlayScreen` has no `PopScope`. Android's back gesture pops the route straight from a running belt to Home, abandoning the run with no pause and no confirmation. Found while building the Milestone 3 gate evidence, not by a user report.
- Evidence: A probe test drove a live run, called `handlePopRoute()`, and landed on Home with the pause scrim never shown and the run discarded. Reproducible on every level. Severity P2 under `docs/testing-strategy.md`: nothing crashes and no score is corrupted, so it is not P0/P1, but a stray edge swipe silently destroys a run in progress.
- Options considered: (a) leave it — back quits, as it does today; (b) `PopScope` that intercepts back and opens the pause scrim instead, so quitting takes a deliberate second tap on `QUIT TO HOME`; (c) confirm-on-back dialog separate from the pause scrim.
- Decision: Option (b). The pause scrim already exists and already carries a quit affordance, so back becomes "hold the belt" and the existing UI does the rest. (c) was rejected because a second modal would say what the pause scrim already says.
- Consequences: one `PopScope` in `PlayScreen` and a test asserting back pauses rather than pops. No design-system change; the pause scrim is already specified. Does not affect the results screen, where back should still leave.
- Owner/gate: human — Gate 3.
- Implemented 2026-08-16: `PlayScreen` wraps its Scaffold in a `PopScope` with `canPop: _paused`. A running belt swallows the back gesture and holds instead; a held belt lets back through and exits. The briefing is unaffected and pops normally, since there is no run to lose. One implementation detail was not specified by this decision and is recorded here: back from a *held* belt exits rather than requiring the `QUIT TO HOME` button, because a back gesture that does nothing at all is worse than one that follows the Android convention. `QUIT TO HOME` remains. Covered by `test/ui/play_screen_test.dart` → *system back holds the belt instead of discarding the run* and *a second back leaves the held belt, so quitting stays possible*.

### 2026-08-16 — Prototype screenshots are web captures, not device captures

- Status: approved (human gate, 2026-08-16)
- Context: Milestone 3's gate needed visual evidence. No Android SDK or emulator is installed on the development machine, so the only way to render the app was the web build.
- Evidence: Seven screens captured from `flutter build web --release` in headless Chrome at 390×844, stored in `docs/screenshots/` and indexed in `docs/milestone-3-gate.md`. The captured passing run produced score 170 and best combo x3, matching `test/scenarios/complete_run_test.dart` exactly — the running app and the test agree.
- Options considered: (a) ship the gate with no visual evidence; (b) web captures, clearly labelled as such; (c) block the gate until an Android SDK is installed.
- Decision: (b). Web captures are honest evidence of layout, hierarchy, and the colour/pattern accessibility contract, and they cost nothing. They are explicitly not evidence of fairness, touch feel, or frame pacing, and the gate report says so.
- Consequences: `docs/screenshots/` adds ~264KB of PNGs to the repository. The Milestone 4 device test remains the only thing that can close the "no P0/P1" criterion. If the screenshots are regenerated after UI changes, the capture recipe is in `docs/milestone-3-gate.md`.
- Owner/gate: human — Gate 3.

### 2026-08-16 — `DAMAGED` defined as a telegraphed shape-shift

- Status: approved (human gate, 2026-08-16)
- Context: `docs/level-spec.md` unlocks a `DAMAGED` stamp at `P=90` in the endless curve but never defines what it does. It is a named slot with no behaviour. Meanwhile the scope ceiling allows two rule modifiers and both are already allocated (`PRIORITY`, `DAMAGED`), so any new chaotic mechanic must either fill this slot or breach the ceiling.
- Evidence: `docs/level-spec.md:79` names the stamp; no document specifies its effect. Originated as a human proposal for "shape shifting shapes" during play testing on 2026-08-16.
- Options considered: (a) leave `DAMAGED` undefined and add a third modifier for chaos — breaches the two-modifier ceiling; (b) define `DAMAGED` as a package whose shape changes once in transit, preceded by a visible unstable state; (c) define `DAMAGED` as a silent shape change with no warning; (d) drop the slot entirely.
- Decision: Option (b). A `DAMAGED` package enters a visibly corrupted state — static or torn fill, not a strobe — for a telegraph window, then re-renders as a different shape drawn from the level's shape pool. Both the morph timing and the target shape come from the run's seeded RNG, so replays reproduce exactly.
- Consequences: The telegraph is the whole mechanic. Option (c) was rejected because a silent change punishes a decision the player already committed to — the thumb is in motion — which contradicts "every failure should be explainable" in `docs/level-spec.md` and is the same unfairness the 1.20s read-window floor exists to prevent. Telegraphed, it teaches a genuinely new skill: withhold the tap until the package settles. That is a fresh axis, since every other pressure in the game rewards speed. Two constraints ride with it: `DAMAGED` and `PRIORITY` must never appear on the same package, because two "the obvious answer is wrong" mechanics stacked read as arbitrary rather than skillful; and the unstable state must respect the design system's no-rapid-flashing rule. The mechanic only bites where shape is load-bearing, so it is inert on the colour-routing levels and hardest at `P=45+` compound — a difficulty gradient that needs no separate tuning. On approval, `docs/level-spec.md` needs the definition and the telegraph duration added.
- Owner/gate: human — Gate 3 (Milestone 4 scope).

### 2026-08-16 — Double-or-nothing as a results-screen wager

- Status: approved (human gate, 2026-08-16)
- Context: A human proposal on 2026-08-16 for a double-or-nothing mechanic. The question was where to put it without spending a rule-modifier slot or complicating the active loop.
- Evidence: Both modifier slots are allocated. The product brief's pitch is "prove you can beat your own best run", which a wager serves directly.
- Options considered: (a) a mid-run stamp that doubles a package's value and doubles the penalty for missing it — requires a third modifier slot; (b) an opt-in wager offered on the results screen after clearing a shift: replay it, clear it again and the score doubles, fail and it scores zero; (c) an automatic double-or-nothing triggered by a combo threshold.
- Decision: Option (b).
- Consequences: Costs no modifier slot and does not touch the active loop at all — the play field, the engine, and the fairness floors are untouched. Trivially seedable because it changes no gameplay randomness. (c) was rejected because an imposed wager makes a loss feel done *to* the player; the general principle applied here is that chaos a player opts into stays explainable, while chaos imposed on them does not. Adds a state to the results screen, which is already pending a design pass under open decision §12.6 — the two should be resolved together rather than separately.
- Owner/gate: human — Gate 3 (Milestone 4 scope).

### 2026-08-16 — Onboarding levels 4–7 stay deterministic

- Status: **superseded** (human gate, 2026-08-16) by *A graduated chaos ramp across levels 4–10*. Left intact rather than edited: the reasoning below is still the reasoning, and the superseding entry has to argue against it rather than pretend it was never made.
- Context: A human proposal on 2026-08-16 to introduce RNG elements — difficulty debuffs, chaotic modifiers — into curated levels 4–7.
- Evidence: `docs/level-spec.md` level principles require teaching one pressure at a time and state "avoid random difficulty spikes; every failure should be explainable." `docs/product-brief.md` already rejected adaptive difficulty for v1 on the grounds that it breaks seed determinism, and a performance-reactive debuff is that same mechanic. `docs/design-spec.md:22` calls the override conflict "the single most important mechanic in the design", previewed at level 10.
- Options considered: (a) introduce chaotic modifiers across levels 4–7 as proposed; (b) keep 4–7 as specified — three colours, combo, queue pressure, near-miss recovery — and confine chaos to endless, where `PRIORITY` and `DAMAGED` already live.
- Decision: Option (b).
- Consequences: Levels 4–7 keep their teaching objectives unchanged. The reasoning is sequencing rather than scope: those levels exist to make the player fluent enough that the override conflict at level 10 lands as a revelation instead of noise, and spending them on chaos buries the mechanic the design is betting on. Chaos still ships in v1 — it arrives in endless via the two stamps. If device testing shows levels 4–7 are dull, the fix is the curve, not a new mechanic.
- Owner/gate: human — Gate 3 (Milestone 4 scope).

### 2026-08-16 — Audio direction and asset pipeline

- Status: approved (human gate, 2026-08-16)
- Context: Milestone 4 lists feedback as in scope and the human intends to generate music with Suno. The prototype ships silent and has no asset pipeline.
- Evidence: `audioplayers` is already inside the three-package runtime budget in `docs/product-brief.md`, so the dependency needs no ceiling change. `pubspec.yaml` currently states "No asset pipeline in v1: shapes, type, and particles are procedural", which audio assets contradict. `docs/design-system.md` requires sound-off play to be supported.
- Options considered: (a) no audio in v1; (b) procedural/synthesised audio only, keeping the no-assets stance; (c) generated music files plus an asset pipeline.
- Decision: Option (c), with the direction taken from the existing identity: the wobble lives in the texture and the grid stays machine-perfect — tape warble, fluorescent buzz, and detuned stabs over a rhythm section that never drifts, instrumented from the depot fiction (conveyor hum, stamp thud, barcode beeps, PA reverb). Intensity varies by pressure band via crossfaded tracks at a shared tempo and key, rather than by stems.
- Consequences: `pubspec.yaml`'s no-asset-pipeline line must be amended, and bundle size becomes a release concern for the AAB. Spawn intervals must **not** be quantised to a musical grid: the approved values (2.6, 2.4, 2.2, 1.9, 1.8, 1.4, 1.4, 1.5, 1.1, 0.95, floor 0.65) are not harmonically related, and forcing them onto a beat would flatten a difficulty curve that is already tuned — so the music sits under the game rather than driving it. Two open items ride with this: Suno's commercial-use terms must be verified against the intended Google Play release and the finding recorded here before any audio ships; and music must be toggleable with no gameplay information carried by audio alone.
- Owner/gate: human — Gate 3 (Milestone 4 scope).

### 2026-08-16 — Gate 3 outcome: Milestone 3 accepted

- Status: approved (human gate, 2026-08-16)
- Context: Milestone 3's acceptance criteria and the twelve outstanding proposals were put to the human gate together, with evidence in `docs/milestone-3-gate.md`.
- Evidence: `flutter analyze` clean and 91 tests passing at the time of the ruling. Five of six criteria carry direct automated evidence; the sixth does not.
- Options considered: (a) accept the criteria with the device-test gap recorded; (b) accept five and hold "no P0/P1 bugs" open; (c) hold the whole gate until the app runs on Android hardware.
- Decision: Option (a). Milestone 3 is accepted and Milestone 4 is open. All twelve proposals outstanding at this gate were approved: the six predating it, the two raised while preparing it, and the four defining Milestone 4's scope.
- Consequences: **"No P0/P1 bugs" was accepted on automated testing alone.** No build has ever run on Android — there is no SDK on the development machine — so layer 5 of `docs/testing-strategy.md` has never executed and this criterion is the weakest claim in the milestone. It carries forward as Milestone 4's first obligation, not as a settled matter. M3-01 was fixed under this gate. M3-02 to M3-04 remain open as P3 polish, with M3-04 folded into the §12.6 results-screen design pass. Design-spec §12.4, §12.5 and §12.6 were **not** ruled on and remain open.
- Owner/gate: human — Gate 3, closed 2026-08-16.

### 2026-08-16 — Level 5's pass condition contradicts the 30–90 second band

- Status: approved (human gate, 2026-08-16) — resolved by option (c), combo x4
- Context: Milestone 4 implements curated levels 4–10. Level 5's approved pass condition in `docs/level-spec.md` is "reach combo x3", and its estimated duration in the same table is ~40s. Those two numbers are not consistent with each other.
- Evidence: Combo tier advances every 5 consecutive correct sorts (`RunScore.tierFor`), so tier 3 is reached on the 10th clean sort. `test/core/pass_condition_test.dart` pins this against the scoring rules rather than asserting it. At level 5's approved spawn interval of 1.8s and read window of 3.0s, a clean run clears the level in roughly 10 × 1.8 + 3.0 ≈ 21s — well under the 30–90 second band that `docs/level-spec.md` sets for every level, and about half its own stated estimate. A player good enough to hold a streak finishes level 5 in a third of a minute; a player who keeps breaking it plays much longer. The level's length varies inversely with skill, which is backwards.
- Options considered: (a) make level 5 compound — sort a count *and* reach combo x3 — which needs an `EveryOf` condition that level 10 requires anyway; (b) raise the spawn interval so ten sorts fills 30s, which would need `S ≥ 2.7` and would make level 5 *easier* than level 4, breaking the "difficulty never eases" guard test; (c) raise the target to combo x4, giving 15 sorts and exactly 30.0s, at the cost of duplicating level 10's combo ask; (d) accept a short level 5 and exempt combo levels from the duration band.
- Decision: none yet. (a) is the recommendation. It preserves the teaching objective — level 5 exists to make the player *chase* the combo — while giving the level a duration floor that does not depend on how well the player is doing. (b) is ruled out by an existing guard test rather than by taste.
- Consequences: **Level 5 is not implemented and levels 6–10 are blocked behind it**, because shipping level 6 without level 5 would leave a gap in the ladder that strands the player. Level 4 shipped, since it is a plain sort target with no such conflict. Adopting (a) means building `EveryOf`, which levels 8 and 10 need regardless. The number in `docs/level-spec.md` would need updating either way — this contradiction is in the spec, not in the code.
- Owner/gate: human — Gate 4.

### 2026-08-16 — Home and briefing overflow at large text scales

- Status: approved (implements an existing rule) — the residual question below is `proposed`
- Context: `docs/testing-strategy.md` lists small screens, large screens, and text scaling as required scenarios. None had tests. Writing them exposed a defect severe enough to be P1.
- Evidence: `test/ui/responsive_test.dart` across four viewports and three text scales. On a 320×568 phone, `HomeScreen` overflowed its column by 146px at 1.5× text and 318px at 2.0×; the briefing overflowed by 156px and 603px. At 2.0× the `PUNCH IN` button rendered at y=619 on a 568px screen — **off the bottom of the display and unreachable by any means, so no run could be started at all**. Landscape viewports overflowed too, which matters because Android may ignore a portrait preference on tablets and foldables. `ResultsScreen` passed every case, because it already scrolls its manifest and pins its actions outside the scroll area — a comment in that file says it exists precisely so restarting can never become unreachable. The same defect it was written to avoid was live on the two screens before it.
- Options considered: (a) shrink type on small screens, which fights the system text-scale setting the design system says to respect; (b) a fit-or-scroll container that keeps the designed composition when it fits and scrolls when it does not; (c) cap the text scale on these screens.
- Decision: Option (b). `lib/ui/widgets/fit_or_scroll.dart` wraps home and the briefing. `IntrinsicHeight` with a `minHeight` of the viewport keeps the spacers distributing slack exactly as before at normal text sizes, and lets the column take its natural height and scroll once it outgrows the screen. Treated as a defect fix rather than a new decision: `docs/design-system.md` already requires system text scaling to be respected outside the game canvas, and the code did not comply.
- Consequences: No visual change at normal text sizes, which `test/ui/responsive_test.dart` pins with an explicit 1× assertion that the button needs no scrolling. **Residual design question, `proposed`:** at 2.0× text on a 320px-wide phone the composition is genuinely taller than the screen, so `PUNCH IN` now sits below the fold and starting a run becomes scroll-then-tap. That is strictly better than unreachable, but it does soften home's stated promise that starting a run takes exactly one tap. Options if that matters: reorder home so the primary action precedes the title block, or cap the effective text scale on home alone. Not decided.
- Owner/gate: human — Gate 4.

### 2026-08-16 — Returning from the background drops the player straight back onto a moving belt

- Status: approved (human gate, 2026-08-16) — option (b), the belt holds on return
- Context: Backgrounding and relaunch are required scenarios in `docs/testing-strategy.md` with no coverage and no explicit design.
- Evidence: `FlameGame.pauseWhenBackgrounded` defaults to true, so Flame pauses its own game loop on `AppLifecycleState.paused` and calls `resumeEngine()` on return (`flame-1.38.0/lib/src/game/flame_game.dart:321`). Nothing in this project handles lifecycle. The practical effect: packages are not lost while the app is away — good — but the belt starts moving again the instant the player returns, with no warning and no `BELT HELD` beat. `RunEngine.phase` stays `running` throughout, so the pause scrim never appears. A player who takes a call mid-shift comes back to a package already near the sort line.
- Options considered: (a) leave Flame's default — instant resume; (b) treat returning from the background as a pause, showing the existing `BELT HELD` scrim so the player resumes deliberately; (c) a countdown before resuming.
- Decision: none yet. (b) is the recommendation, and it is nearly free — the scrim, the resume path, and the engine pause all already exist, and it matches the ruling already made for the back gesture, where an interruption holds the belt rather than acting on it. (c) introduces a UI element the design does not otherwise have.
- Consequences of (b): a lifecycle observer in `PlayScreen` that calls the same `_togglePause` path the back gesture now uses. No design-system change. Would need a test simulating the lifecycle transition.
- Owner/gate: human — Gate 4.

### 2026-08-16 — A graduated chaos ramp across levels 4–10

- Status: approved (human gate, 2026-08-16) — option (b), chaos begins at level 5. Unblocked and live on levels 5–6 as of 2026-08-17.
- Context: Supersedes *Onboarding levels 4–7 stay deterministic*, approved earlier the same day. The human's revised intent: chaos should be introduced gradually across the back half of onboarding — controlled first, escalating to maximum by level 10 — rather than being withheld until endless.
- Evidence: The superseded entry's reasoning was sequencing, not safety, and a *graduated* ramp answers it in a way an abrupt introduction did not. Its real concern was stacking a second new thing onto a level that already teaches one; that concern survives and shapes the ramp below rather than blocking it. The distinction that keeps chaos fair is unchanged and load-bearing: **telegraphed chaos is explainable, silent chaos is not.** This ramp escalates by raising frequency and shortening the warning, never by removing it.
- Options considered: (a) chaos from level 4; (b) chaos from level 5, leaving level 4 clean because introducing the third hue is already that level's one new pressure; (c) chaos only from level 8.
- Decision: none yet. (b) is the recommendation. Chaos is expressed as two data fields on `LevelConfig` — `chaosRate`, the chance a spawned package is `DAMAGED`, and `telegraphSeconds`, how long its corrupted state shows before it changes — so the ramp is tuning data, not new mechanics, and stays inside the two-modifier scope ceiling. Proposed curve: L4 `0.00`; L5 `0.10 / 1.2s`; L6 `0.15 / 1.0s`; L7 `0.20 / 0.8s`; L8 `0.25 / 0.7s`; L9 `0.30 / 0.6s`; L10 `0.35 / 0.5s` alongside `PRIORITY`.
- Consequences: Level 5 gains a second reason to exist — it teaches the player to want a combo, and chaos is what threatens one, so the pressure it teaches and the pressure it applies point at the same thing. Level 4 stays clean under (b); overriding that is the human's call and the only real cost is a mild "random difficulty spike" on the level introducing the third hue. `DAMAGED` appearing from level 5 makes its `P=90` endless unlock a re-introduction rather than a first meeting, which matches how `PRIORITY` is already previewed at level 10. The telegraph floor of 0.5s must not be lowered without device-test evidence, for the same reason the read-window floor exists. `docs/level-spec.md` needs the two columns added on approval.
- Owner/gate: human — Gate 4.

### 2026-08-16 — Play-field effects may carry information

- Status: approved (human gate, 2026-08-16)
- Context: `lib/game/components/hud_component.dart` states in a comment that the error channel-split and the combo misregistration "are the entire experimentation budget for the play field", enforcing the 20/80 novelty split in `docs/design-system.md`. The human asked for particle and glitch effects in the CRT/zine idiom.
- Evidence: `CLAUDE.md` explicitly endorses "procedural shapes, typography, particles, and simple sound before adding an asset pipeline", so particles are in-constitution and need no asset budget. What they were not clearly inside was the play field's novelty allowance.
- Options considered: (a) confine new effects to home and results, where the budget is already 60%; (b) allow play-field effects that are tied to an outcome; (c) raise the 20/80 split outright.
- Decision: Option (b). Effects during active play are allowed when they carry information — a package dissolving on a correct sort, a tear on a misroute, the `DAMAGED` corrupted state — and are not allowed when they only decorate. The test is whether removing the effect loses the player something they could have acted on.
- Consequences: (c) was rejected because "gameplay clarity beats visual novelty" is a `CLAUDE.md` non-negotiable and the 20/80 split is how it is enforced; this decision reinterprets what counts against the budget rather than enlarging it. The `hud_component.dart` comment is now wrong and must be updated when the first such effect lands. Two constraints ride along: `docs/design-system.md` forbids rapid flashing, which a CRT roll or a strobing glitch would trip, and `docs/design-spec.md` §11.13 requires 60fps with five active packages on a mid-range device. **That frame-rate target has never been measured, because the app has never run on Android.** Particle work is the classic thing that looks fine in a browser and drops frames on real mid-range hardware, so the device test should precede any heavy effect, not follow it.
- Owner/gate: human — Gate 4.

### 2026-08-16 — Performance is measured before it is optimised

- Status: approved (implements an existing requirement)
- Context: `docs/design-spec.md` §11.13 requires 60fps with five active packages on a mid-range device, and the approved effects work is the kind that threatens it. Nothing in the project measured anything, so any optimisation would have been guesswork.
- Evidence: Two harnesses now exist. `tool/benchmark_core.dart` runs headless under plain `dart run` — possible only because `lib/core` imports neither Flame nor Flutter, so the architectural rule paid for itself here. `test/perf/render_cost_test.dart` measures CPU paint cost and prints a per-component breakdown. Findings: **the simulation is free** at roughly 0.1us per frame, 0.001% of a 60fps budget even at the fairness floors with five packages and chaos on — optimising `RunEngine` would have been pure waste. **The chutes were 41% of the frame**, 137us of 333us, redrawing identical pixels sixty times a second including a full text layout per chute per frame.
- Options considered: (a) optimise by inspection; (b) measure first, then optimise what the measurement names.
- Decision: Option (b), and it immediately proved its worth. The first round of optimisation was chosen by inspection — caching HUD text, hoisting `Paint` allocations — and measurement showed **no improvement at all** (417us before, 436us after, inside noise). Caching each chute's static layer into a `Picture`, rebuilt only on resize, took the frame from 333us to 142us. A 57% reduction from the change that was measured, and nothing from the change that was assumed.
- Consequences: The allocation-reducing changes were kept despite showing no wall-clock win, because fewer per-frame allocations still means less GC pressure than this harness can observe — but they are recorded here as unproven rather than as a success. Guard tests are structural, not timing-based: they assert that `RunEngine.active` returns a live view rather than a per-frame copy and that draining an empty event queue allocates nothing, which are exact and fail for a real reason, where wall-clock thresholds would be flaky. **Neither harness sees the GPU.** Rasterisation is where a real device falls over and no test on this machine can observe it, so a good number here is a regression signal and never evidence of 60fps.
- Owner/gate: human — Gate 4.

### 2026-08-16 — `DAMAGED` corrupts the wrong attribute on colour-routed levels

- Status: approved (human gate, 2026-08-17) — option (a), implemented same day
- Context: The approved chaos ramp starts at level 5. Implementing it exposed that the mechanic does nothing there.
- Evidence: `DAMAGED` was approved as a package that "re-renders as a different shape", and `RunEngine` implements exactly that. But levels 3–7 use `ColorRouting`, whose `binFor` reads `colorIndex` and ignores shape entirely (`lib/core/routing.dart:72`). A damaged package on levels 5, 6 or 7 would flicker into its corrupted state, visibly change silhouette, and **route to precisely the same chute as before**. The mechanic is inert on every level the ramp was approved to start on.
- Options considered: (a) `DAMAGED` corrupts whichever attribute the level routes on — shape on shape-routed levels, hue and pattern on colour-routed ones; (b) start the chaos ramp at level 8, where compound routing makes shape load-bearing again; (c) switch levels 5–7 to shape routing, which would undo the attribute switch levels 3–4 exist to teach.
- Decision: none yet. (a) is the recommendation and fits the fiction better than the original wording did — a `DAMAGED` parcel is one whose *label* cannot be trusted, and the label is whatever that shift is reading. It also keeps the ramp starting where it was approved to start. (c) is rejected outright: it would dismantle the approved attribute-precedence ladder.
- Consequences: **Shipping the ramp as approved would be worse than shipping no chaos at all.** A package that glitches dramatically and changes nothing teaches the player that glitching is decorative; level 8 would then punish them for having learned it, which is the opposite of what an onboarding ladder is for. Chaos is therefore held at zero on every level until this is resolved — the mechanic and its tests are in place and inert, and turning it on is a data edit. Option (a) needs `RoutingRule` to expose which attribute it reads, so the engine can corrupt the one that matters; roughly a day's work including tests, and it strictly widens the approved mechanic rather than replacing it.
- Owner/gate: human — Gate 4.

### 2026-08-16 — An overlay does not count against the four-screen ceiling

- Status: approved (human gate, 2026-08-16)
- Context: The scope ceiling in `docs/product-brief.md` allows four distinct screens — Home, Play, Results, Settings. It was unclear whether an in-run overlay counts as one, which blocked any proposal involving a mid-run panel.
- Evidence: The pause scrim already works this way and was never counted against the ceiling.
- Options considered: (a) overlays count as screens; (b) they do not.
- Decision: Option (b). A screen is a navigable destination; an overlay drawn over an existing one is not. The ceiling still binds destinations.
- Consequences: Mid-run panels are no longer ceiling-blocked. The ceiling's intent — that this stays a small game — now has to be held by judgement rather than by the count, since overlays are unbounded. Settings remains budgeted but unbuilt.
- Owner/gate: human — Gate 4.

### 2026-08-17 — `DAMAGED` corrupts the routed attribute: implemented

- Status: approved (human gate, 2026-08-17)
- Context: Closing out the contradiction recorded the previous day, where `DAMAGED` changed shape while levels 3–7 routed on hue.
- Evidence: `RoutingRule` now exposes `RoutedAttribute reads`, and `RunEngine._spawn` builds the corruption from that — a different silhouette on shape-routed levels, a different hue and its paired pattern on colour-routed ones. The guard test asserts the property that actually matters and holds on both: `routing.binFor(morphTo) != routing.binFor(spec)`, checked across forty seeds. The old test asserted "the shape changed", which passed on colour-routed levels while the mechanic did nothing whatsoever — the assertion was as inert as the code it was guarding.
- Options considered: recorded in the superseded contradiction entry.
- Decision: Option (a). Chaos is now live on levels 5 (`0.10 / 1.2s`) and 6 (`0.15 / 1.0s`).
- Consequences: `ActivePackage.morphTo` is a full `PackageSpec` rather than a `PackageShape`, which is simpler and carries whichever attribute changed. Two new guard tests hold the ramp honest: the telegraph may never fall below 0.5s or exceed the level's own read window, and the chaos rate may never ease as levels advance — the same shape as the existing difficulty guard. Levels 7–10 still carry no chaos because they do not exist yet; the ramp values for them are recorded but unimplemented.
- Owner/gate: human — Gate 4.

### 2026-08-17 — Building on Windows against a WSL working tree

- Status: approved (implements an existing requirement)
- Context: The Android SDK, JDK, USB access and an emulator all live on the Windows side; the repository is on `E:` and reachable from both. Getting a device build required deciding where the build runs.
- Evidence: WSL has a Java 11 JRE with no compiler, no Android SDK, and no USB passthrough — three gaps against Windows's one, which was Flutter itself. The repository also sits on `/mnt/e`, so every Gradle file operation from WSL crosses the 9p bridge. Flutter 3.47.0 was installed to `E:\flutter-sdk`, matching the WSL install and `.metadata` revision `4cf2416426` exactly.
- Options considered: (a) install JDK 17+ and a Linux Android SDK in WSL and build there; (b) install Flutter on Windows and build there; (c) point WSL's Flutter at the Windows SDK.
- Decision: Option (b). (c) was rejected because a Linux Flutter needs Linux `adb` and build-tools binaries, and would still build across the slow filesystem bridge.
- Consequences: **The two installs share one `.dart_tool/`, and whichever side ran last owns it.** The first Windows build failed with `Method not found: 'TextSpan'` and two similar errors in `lib/game/text_util.dart` — source that was, and remains, correct. `package_config.json` still pointed at `file:///home/aswinawien/flutter/packages/flutter`, which Windows cannot read, so `package:flutter/painting.dart` resolved to nothing and every symbol in it vanished. The compiler error names the wrong culprit convincingly. `flutter clean && flutter pub get` on the side you intend to use fixes it, and switching back requires the same on the other side. Also noted: `flutter doctor` reports `cmdline-tools` missing and licences unverifiable, but Gradle read the accepted licences in `SDK/licenses/` without complaint — the warning is about verification, not about a real gap. Debug symbols are not stripped because no NDK is installed; this inflates the upload but not the download.
- Owner/gate: human — Gate 4.

### 2026-08-17 — D-01: the HUD renders underneath the Android system status bar

- Status: approved (human gate, 2026-08-17) — option (c), both halves; **fixed and verified on device the same day**
- Context: The first run of this game on an actual Android device, minutes after the toolchain came up. Found immediately.
- Evidence: `docs/screenshots/device/03-play.png` and `04-play-level5.png`, captured from `emulator-5554` at 1080×2400. `GameWidget` is `Positioned.fill` inside a `Stack` with no `SafeArea`, so the Flame canvas covers the entire physical screen and `HudComponent` draws at y=0 — underneath the system status bar. On level 1 the score sits behind the clock and `NO PENALTY` runs through the signal, wifi and battery icons. On level 5 it is materially worse: **the three mistake pips render directly on top of the status icons**, and a spent pip reads as part of the signal indicator. The tell was visible in the same screenshot — the Flutter pause button sits clear of the icons, because that one *is* wrapped in a `SafeArea`. Every web capture in `docs/screenshots/` missed this because a browser has no status bar.
- Severity: P1 under `docs/testing-strategy.md` — "core loop or score broken". The mistake pips are the player's life counter and the score is the thing the whole game is for; both are illegible against system chrome during active play. Nothing crashes, so it is not P0.
- Options considered: (a) offset HUD content by the top safe-area inset, leaving the belt and chutes using the full canvas; (b) hide the system bars during play with an immersive mode, giving the design the whole screen; (c) wrap `GameWidget` in a `SafeArea`, which would shorten the play field and change the §8 vertical fractions.
- Decision: none yet. (c) is rejected — it silently rescales the play field and the fairness timings are expressed in that geometry. Between (a) and (b): (a) is a minimal correction and asserts nothing new about the design; (b) is conventional for a fullscreen arcade game and fits the identity, but it is a whole-app visual change and immersive modes interact with edge-swipe gestures, which now matter because back holds the belt.
- Consequences: **Gate 3 accepted "no P0/P1 bugs" on automated testing alone, and the first device run produced a P1.** That is the clearest possible argument for the device test being Milestone 4's first obligation, and it should be recorded as such rather than treated as bad luck. No amount of widget testing would have found this: `flutter test` has no system chrome.
- Owner/gate: human — Gate 4.

### 2026-08-17 — D-01 fix verified on device

- Status: approved (human gate, 2026-08-17)
- Context: Closing D-01 with device evidence rather than a passing test suite, since a passing test suite is exactly what missed it.
- Evidence: `docs/screenshots/device/05-play-fixed.png`, captured from `emulator-5554` after reinstalling the rebuilt APK. The system bars are gone, and the score, combo and all three mistake pips are legible with nothing occluding them. The same capture incidentally confirms two other approved decisions working on real hardware: the three chutes carry solid, hatch and dotted swatches with no identifying colour, and the package on the belt is a pink *hatched* circle — the hue-pattern pairing that makes the game playable in greyscale.
- Options considered: recorded in the D-01 entry.
- Decision: Both halves shipped. `PlayScreen` enters `SystemUiMode.immersiveSticky` on init and restores `edgeToEdge` on dispose; `SortRushGame.safeTop` is pushed from `MediaQuery.paddingOf(context).top` on every build.
- Consequences: **Only the HUD is inset — the belt and chutes keep the full canvas.** `docs/design-spec.md` §8's vertical fractions are the geometry the fairness timings are expressed in, so insetting the whole canvas would silently rescale the play field and change what a 1.20s read window means on a notched phone. The HUD offset is clamped to 60% of the status band so a pathological inset cannot collapse it. The inset is not redundant with immersive mode: a display cutout keeps occluding whether the bars are hidden or not. `immersiveSticky` rather than plain immersive, so a stray edge swipe does not leave the bars parked over the belt for the rest of a run — which matters more now that the back gesture holds the belt.
- Owner/gate: human — Gate 4.

### 2026-08-17 — Clutch saves defined, and three deviations found building levels 7–9

- Status: approved (human gate, 2026-08-17) for the clutch definition; the deviations below are `proposed`
- Context: Finishing onboarding required §12.4 to be answered and levels 7–9 to be built. Building them surfaced three disagreements between the approved table and its own rules.
- Evidence: `test/core/clutch_save_test.dart` and `test/core/levels_test.dart`.
- Decision: A clutch save is a correct sort made with 0.5s or less remaining before the sort line. It pays a flat 5-point bonus on top of the combo-scaled base, and level 7's condition is `EveryOf([SortTarget(20), ClutchTarget(2)])` — volume alone would let a player clear it without ever cutting it fine, which is the one thing the level exists to teach. The window is measured in seconds rather than progress, so it means the same thing on a slow level and a fast one.
- Deviations found, all `proposed`:
  1. **Level 8 asks for 19 correct, not the 18 in `docs/level-spec.md`.** At its approved 1.5s spawn interval, 18 clears in 29.6s — under the spec's own 30–90 second band. One extra package puts it at 31.1s.
  2. **Level 8's "≤1 misroute" is not implemented.** It is a constraint rather than a target, and it raises a question the design has never answered: once a player exceeds it the level can no longer be passed, but the mistake limit is 3, so they would play on knowing they cannot win. Failing the run immediately is one answer and letting it run out is another; neither is obviously right, so nothing was invented. Level 8 currently ships as a plain sort target.
  3. **A guard test was wrong, not the data.** "Difficulty never eases as levels advance" failed at level 8, which the approved table gives a *longer* read window and spawn interval than level 7. That is deliberate: level 8 introduces compound reading, and teaching one pressure at a time means relieving another to make room. The guard now permits easing exactly where the routing rule changes and forbids it everywhere else.
- Consequences: `CompoundRouting` owns one exact (shape, hue) pair per chute, with two chutes sharing a shape and two sharing a hue so neither attribute alone disambiguates. Because most of the cross product then owns no chute, `LevelConfig.spawnPool` restricts what a compound level may spawn, and the "every package has a destination" guard now checks the pool rather than the cross product.
- Owner/gate: human — Gate 4.

### 2026-08-17 — Level 5 teaches `DAMAGED`, and escalation is the shrinking warning

- Status: approved (human gate, 2026-08-17 — "I'll leave it up to you")
- Context: Chaos had been live on levels 5–9 since the ramp was approved, and **no level taught it.** Level 5's briefing talked about combo streaks; nothing anywhere told the player a package could change. A player who misrouted because a package morphed had no way to know why.
- Evidence: `docs/level-spec.md` requires teaching one pressure at a time and states that every failure should be explainable. Injecting a mechanic with no introduction fails both. The same document also states that combo is active and displayed from level 1 and that level 5 only makes the player *chase* it — so level 5 was the one slot in the ladder teaching a scoreboard concept rather than an action, which made it the right slot to reclaim.
- Options considered: (a) add an eleventh level for chaos, breaching the ten-level ceiling; (b) give the mechanic level 5, whose existing objective changes nothing the player does; (c) leave chaos untaught and rely on players inferring it.
- Decision: Option (b). Level 5 becomes `DAMAGED GOODS` — "SOME LABELS GO BAD. WAIT FOR THEM TO SETTLE." — and keeps its combo x4 target. The two reinforce rather than compete: chaos is precisely what breaks a streak, so the pressure the level teaches and the pressure it applies are the same pressure.
- Consequences: Chaos is now **concentrated** at level 5 (0.30) and diluted afterwards (0.20 at level 6) as other pressures arrive. That inverted an existing guard, which asserted the rate never eases — and the guard was wrong for the same reason the "difficulty never eases" guard was wrong at level 8: **a teaching level concentrates its new mechanic, then later levels dilute it among others.** The replacement guard asserts what actually measures difficulty — *the telegraph only ever gets shorter* — plus a new guard that whichever level introduces chaos must carry at least 0.25 of it, because a mechanic met once every ten packages reads as an oddity rather than a rule. Escalation in this game is the shrinking warning, not the rising rate.
- Owner/gate: human — Gate 4.

### 2026-08-17 — Endless shop: Balatro-style RNG in the offer, not in the tap

- Status: approved (human gate, 2026-08-17) — option (b), endless only
- Context: Human request to add an RNG mechanic like Balatro. Three related notes already sit in `docs/backlog.md` — a Vampire Survivors-style mid-run draft, a within-run pay/powerup economy, and dynamic chutes — plus the approved intent that endless should feel distinct from curated levels. They are one system if designed together and three that fight if designed apart. The question is which slice of Balatro this game can take without breaking the pitch, the fairness floors, or the two-stamp ceiling.
- Evidence:
  - Balatro's RNG the player *feels* is the shop and the packs: three things appear, you pick, then you play a skill round whose rules you opted into. The same seed produces the same shop. Probability that resolves *after* a committed play (Lucky Card analogues) is the part that does not travel.
  - This project's existing fairness contract is the same idea in different clothes. `DAMAGED` was approved as a telegraph and rejected as a silent morph because a change after the thumb is in motion is unexplainable (`docs/decision-log.md`, 2026-08-16). Double-or-nothing was approved as an opt-in on results and rejected as an automatic trigger for the same reason: chaos a player chooses stays explainable; chaos imposed on them does not. Adaptive difficulty was rejected at Gate 2 because it breaks seed determinism.
  - `SeededRng` is already the only RNG. `ActivePackage.readWindow` is already anchored at spawn so a mid-run parameter change cannot speed up packages in flight (`test/core/read_window_anchor_test.dart`). Overlays do not count against the four-screen ceiling. Fairness floors (read window 1.20s, spawn 0.65s, telegraph 0.5s) are approved clamps.
  - Product-brief v1 exclusions include complex inventory and a procedural level generator. `CLAUDE.md` forbids monetization until repeat play is demonstrated by human testing — a persistent wallet is that machinery even if it is not real money. The pitch is "prove you can beat your own best run"; purchased power that survives a run makes runs incomparable.
  - Both stamp slots are spent (`PRIORITY`, `DAMAGED`). Curated levels are 30–90s; a shop inside one eats a third of the lesson. Endless is specified and not built. Level 10 / `PRIORITY` is not built. Double-or-nothing is approved and not built.
- Options considered:
  - (a) **Vampire Survivors draft.** Belt holds, pick 1 of 3 cards that re-tune existing parameters. Always a gift. Endless only. Cheap, and already sketched. Weakness: no cost, so every pick is upside and "skip" is never rational. Also pauses the rush on a timer, which is the opposite of this game's pressure.
  - (b) **Balatro shop between endless blinds.** Endless is scored in pressure-band "shifts". Between them the belt is held and a seeded overlay offers a small buy list drawn from a data-driven card pool. Pay is earned this run only; every run starts at 0. Cards re-tune existing knobs (spawn, read window, max active, chaos rate, telegraph, score multiplier, mistake pips) and are hard-clamped to the fairness floors. Skip is always legal. One concrete exception from the backlog: a disposable extra chute that absorbs a package, **and using it breaks the combo**, so it is a decision rather than a free life. No new stamp. No fourth chute as a default — that still needs its own ceiling breach if it is ever a card.
  - (c) **Lucky-package RNG.** A sort has a 1-in-N chance to pay extra or to fail. This is Balatro's probability jokers transplanted onto the tap. Rejected: it is silent resolution after commit, the same failure mode as an untelegraphed `DAMAGED`.
  - (d) **Persistent jokers / wallet across runs.** Collection-building. Rejected: complex inventory, incomparable personal bests, and monetization-shaped machinery before any human has played.
  - (e) **Do not add.** Endless stays the data-driven curve plus the two stamps plus the results wager. Safest. Does not make endless feel like its own mode.
- Decision: **Option (b)**, and only for endless. Curated 1–10 stay a teaching ladder; a shop there would bury the one-pressure-at-a-time rule. (c) and (d) are rejected even as future options — they contradict approved fairness and the pitch. (a) remains the fallback if a shop-plus-economy proves too much for the vertical slice; it can be upgraded to (b) later because both are overlays over a held belt.
- Consequences if (b) is approved:
  - Three backlog notes become one system. Dynamic chutes are a *card effect*, not a parallel feature. Double-or-nothing can stay the curated-results wager and also appear as an endless shop card; they should not be designed as two press-your-luck systems that ignore each other.
  - Needs a `CardSpec` / shop draw in `lib/core`, seeded from the run RNG, with tests that the same seed plus the same buys reproduces the run. The belt must hold before the overlay appears — packages in flight keep their anchored read windows. Fairness-floor clamps are guard tests, not comments.
  - Does not spend a stamp slot, does not add a screen, does not add a third-party package. It is not a procedural level generator: the endless curve remains the base, cards only retune it.
  - **Do not build this before endless exists, and do not build endless before Level 10 / `PRIORITY`.** A shop feeding a mode that is not playable is the roof-first problem the `DAMAGED`-on-colour-routing entry already named. Device-measured fairness floors should precede any card that tightens them, even with clamps.
  - Scope risk: a card pool is content. v1 pool should be a short list of parameter retunes plus the disposable chute, written as data next to `levels.dart`, not a design-your-own-joker language.
- Owner/gate: human — Gate 4.

### 2026-08-17 — Endless shop approved: what was decided, and what is already built

- Status: approved (human gate, 2026-08-17)
- Context: The preceding entry was written by another agent (Cursor) and left `proposed` with "Decision: none yet". The human then approved a plan implementing its option (b). Recorded here so the log does not read as though a system was built against an undecided entry. The preceding entry's status and decision lines were updated in place to match the ruling; its context, evidence and options are untouched.
- Evidence: Research into Balatro, Vampire Survivors and Slay the Spire produced the framing that now governs the whole system, and which restates this project's existing fairness rule in general terms. **Input randomness** resolves *before* the player decides — draw a hand, then choose — and feels fair. **Output randomness** resolves *after* they commit — you tapped, then dice decided — and feels like cheating. `DAMAGED` was approved as a telegraph and rejected as a silent morph for exactly this reason; the framing simply names it. It is now the acceptance test for every card: **any card whose text contains a probability is rejected on sight.**
- Options considered: recorded in the preceding entry.
- Decision: Option (b), plus five design commitments that came out of planning and are not in that entry:
  1. **A package's timing is frozen at spawn.** `readWindow` and `telegraphSeconds` live on `ActivePackage`. Required by endless *independently of the shop*: `T(P) = 4.0 − 0.030P` steps on every correct sort, so without the freeze **sorting one package instantly speeds up every other package already in the air** — output randomness produced by the base curve.
  2. **The shop opens on a drained belt.** Crossing a quota threshold stops spawning; the shop opens only when the belt is empty. A purchase is therefore *always* applied to an empty belt — structural, not arithmetic — and the drain is itself a telegraph. This matches the approved ruling that an interruption holds the belt rather than resuming onto a loaded one.
  3. **Modifiers go through an indirection layer, not a `LevelConfig.copyWith`.** `SortRushGame` holds its own `final LevelConfig` and `HudComponent` reads `game.level.mistakeLimit`; swapping the engine's config would make the mistake pips show a number that is not the number that ends the run.
  4. **Deltas are additive only**, so a stack is a sum and purchase order cannot change the result — "which card did that" stays answerable. Money is integer, so replay stays exact.
  5. **The fairness-floor clamp lives in the indirection layer**, not in each card, which makes "no stack of cards can breach 1.20s / 0.65s" structurally true rather than something every card must remember.
- Consequences:
  - **Built already**: the per-package freeze, and a guard that packages never overtake each other. Overtaking is newly possible in principle because frozen windows let packages travel at different speeds; it cannot happen at the current curve — it would need more than 21 correct sorts between two consecutive spawns — but the constraint binds any future tuning change, so it is pinned by test rather than by argument. 175 tests passing.
  - **`PRIORITY` is not implemented at all.** `PackageStamp.priority` is an enum value no `RoutingRule` reads. Endless as specified unlocks it at `P=65` and level 10 is specified around it, so **neither can ship complete until it exists**. This is the one dependency outside the shop work's own scope.
  - **The spec's `P`-based kind unlocks would change the routing rule mid-run**, which changes what the chutes mean while packages are in flight — the same failure mode the silent shape-shift was rejected for. Proposed instead: hold the chutes fixed for a whole run and express unlocks as spawn-pool growth only. Needs its own ruling.
  - **The reproducibility contract grows.** "Same seed reproduces a run" becomes "same seed **plus the same taps plus the same shop choices**". Any replay harness must record card ids, rerolls and skips. Named here so it is not discovered through a confusing bug report.
  - The shop draws from its own `SeededRng` derived from the run seed, never the engine's, so shop behaviour cannot shift package spawns.
- Owner/gate: human — Gate 4.

### 2026-08-17 — Dynamic chutes in endless: count progression, lane swapping, morphing

- Status: proposed
- Context: Human proposal to expand beyond a fixed three-chute layout in endless, on the argument that fixed layouts hit an autopilot ceiling where muscle memory takes over and the game becomes a rhythm exercise. Three mechanics were proposed: chute count progression (2→4), lane swapping (two chutes exchange positions on a warning), and chute morphing (a chute changes what it accepts).
- Evidence:
  - The autopilot argument is sound and is the strongest case yet for this. Every other pressure in the game escalates *speed* — read window, spawn interval, packages on the belt. Changing the board is the only proposal that escalates *uncertainty*, which is a different axis and the one most likely to make endless read as its own mode.
  - **Touch targets are not the binding constraint.** At 360dp wide with the existing 8dp gap: three chutes give 115dp each, four give 84dp, five give 66dp — all comfortably past the 48dp minimum. Width does not bite until roughly seven chutes. The real cost of a fourth chute is reading time, not aim.
  - The scope ceiling fixes bins on screen at 3, so 2→4 breaches it in both directions.
  - Endless currently uses `CompoundRouting` with three chutes owning three specific (shape, hue) pairs, so a two-chute opening cannot use that rule and needs its own routing set.
  - Levels 8–10 were proposed as the teaching slots. **All three are already booked** — 8 is compound reading, 9 is `PRIORITY`, 10 is the shop preview — and level 10 does not exist while `PRIORITY` is unimplemented. The ten-level ladder is the scarce resource here, not the ideas.
- Options considered: (a) all three mechanics; (b) count progression only; (c) count progression and lane swapping, rejecting morphing; (d) none.
- Decision: none yet. **(c) is the recommendation.**
  - **Count progression** is the strongest and the cheapest to reason about. Needs a ceiling ruling and a routing set for a two-chute opening.
  - **Lane swapping** is viable under one rule, stated below. Cadence of 20–30s over a 2–4 minute run gives 4–8 swaps, which is reasonable.
  - **Morphing is recommended against.** It is `DAMAGED` applied to the chute rather than the package, and the blast radius is categorically different: a corrupted *package* changes one answer the player can see and wait out, while a morphing *chute* changes the answer for everything on the belt at once. It also does the same cognitive work as `PRIORITY`, which flips which attribute is read. Two mechanics both meaning "the rule just changed" tend to read as noise rather than depth.
- **The telegraph rule, which is the load-bearing part**: the proposal suggested a fixed 1.5–2s warning. The correct rule is that **the telegraph must be at least as long as the current read window**. If it is, every package on the belt spawned *after* the warning appeared, so nobody was ever committed under the old layout — which is what converts a chute change from output randomness into input randomness. A fixed 1.5–2s happens to clear the 1.20s endless floor, but early in a run the read window is 4.0s and a 2s warning would leave packages mid-flight that were read under the old chutes. Express it as `telegraph >= tuning.readWindow`, not as a constant.
- Consequences: Any of this needs a ceiling ruling first. The alternative that costs no ceiling change is to keep three chutes and vary what they *contain* through the spawn pool, which is already how the endless kind-unlock deviation is proposed to work.
- Owner/gate: human — Gate 4.

### 2026-08-17 — XP bar and roguelite upgrades: what fits, and what would break

- Status: proposed
- Context: Human proposal for a Vampire Survivors-style XP bar feeding a mid-run three-card shop, with a set of candidate upgrades. Much of it converges with the already-approved endless shop; a few items would break mechanics that are already built.
- Evidence and assessment, item by item:
  - **The XP bar already exists — it is the pressure index `P`.** `RunEngine.pressure` is `score.sorted`, it increments per correct sort, it never decreases, and it already drives the difficulty curve and the shop thresholds. Presenting it as a filling bar is a **presentation change, not a new system**, and it should not become a third counter alongside score and pay. Two currencies are already the most this run length can carry.
  - **Micro-break pacing** is a real benefit and is already how the shop is designed: crossing a threshold drains the belt before the panel opens, so the pause is earned rather than jarring.
  - **The Flutter overlay recommendation is right, but `game.overlays.add(...)` is not.** `docs/decision-log.md` records that pause is a Flutter `Stack` rather than a Flame overlay *because it must reach `Navigator` for "quit to home"*. The same reasoning applies to a shop panel. The overlay is a Flutter child of the existing `Stack`, wrapped so it claims its own hits — `_PauseScrim` is a `ColoredBox` and taps reach through it.
  - **`Auto-Sorter` (sorts one item every 5s) — rejected.** The core loop is observe, choose, tap. An upgrade that removes the tap removes the game, and it inflates a score that the pitch says should measure the player.
  - **`Magnet` (draws near-miss items into the correct chute) — rejected.** It destroys the clutch save, which is level 7's entire lesson and is already built and tested, and it decides an outcome the player did not.
  - **`Shield` (protects against one wrong sort without breaking combo) — rejected as written.** Whether it fires is determined *after* the tap, which is output randomness — the same failure the silent shape-shift was rejected for. The legible version already exists in the planned card set: `+1 MISTAKE ALLOWED`, known before you tap rather than discovered after.
  - **`Fever Time` cites a 10x combo, but the combo caps at x5** (`RunScore.maxTier`). Factual mismatch, and worth noting because it suggests the upgrade set was designed against an imagined scoring model rather than the one that exists.
  - **Timed effects (`Fever Time`, `Time Dilator`) — recommended against.** A conveyor slowdown that begins while packages are in flight either applies to them, which changes a deadline mid-decision, or does not, which is invisible and confusing. The approved design makes every modifier permanent for the run and applies it on a drained belt precisely to avoid this. `SLOW BELT` in the planned set does the same job without a timer.
  - **`Chute Lock`** depends on lane swapping, which is unruled.
- **The framing point, recorded because it is a design decision and not a detail.** The proposal argues the shop's value is a "variable ratio reward (the slot machine effect)" producing "a natural dopamine spike". That is precisely what Frank Lantz's Balatro essay warns about — that such systems work "by manipulating the cause and effect mechanism in your brain" — and `CLAUDE.md` forbids monetization until repeat play has been demonstrated by human testing, with that machinery being the concern. A shop that presents a real decision and a shop tuned to produce anticipation spikes are different products. The pitch, "prove you can beat your own best run", is a skill claim. **The recommendation is to keep designing for the decision and let any dopamine be a side effect rather than the target.**
- Options considered: (a) adopt the upgrade set as proposed; (b) adopt the XP presentation and the pacing, reject the four upgrades that decide outcomes for the player, keep the planned give-and-take card set; (c) reject wholesale.
- Decision: none yet. **(b) is the recommendation.**
- Consequences: Under (b) the only new work is presentational — drawing `P` as a filling bar — plus the shop already planned. No new counter, no new currency, and no upgrade that plays the game on the player's behalf.
- Owner/gate: human — Gate 4.

### 2026-08-17 — Correction: the ban on timed effects was too broad

- Status: approved (human gate, 2026-08-17)
- Context: The entry *XP bar and roguelite upgrades* recommended against timed effects outright, on the grounds that a change beginning while packages are in flight moves a deadline mid-decision. A later proposal — a memo granting 100% corrupted packages for twenty seconds at quadruple score — showed that reasoning was overgeneralised.
- Evidence: `chaosRate` is read **only in `_spawn`**. Packages already on the belt captured their own `readWindow` and `telegraphSeconds` at spawn and are untouched by any later change. So a timed chaos window cannot alter a decision already in progress. The same is true of `scorePercent` and `payPercent`, which are read at the moment a sort is scored. What is *not* safe is a timed change to **timing** — read window and spawn interval — because those govern deadlines for things already in the air, which is the hazard the per-package freeze exists to prevent.
- Options considered: (a) keep the blanket ban; (b) narrow it to the parameters that actually govern in-flight deadlines.
- Decision: Option (b). **Timed changes to read window and spawn interval remain forbidden. Timed changes to chaos rate, score rate and pay rate are permitted**, because they take effect at spawn or at scoring and can never reach a package the player is already reading.
- Consequences: This reopens a category previously closed, including localised "challenge window" effects — opt-in bursts of high chaos for high reward, which are input randomness because the player accepts the terms before the window starts. Supersedes the timed-effects half of *XP bar and roguelite upgrades*; the rest of that entry stands.
- Owner/gate: human — Gate 4.

### 2026-08-17 — Depot fiction, contracts, and three new sorting mechanics

- Status: proposed
- Context: A batch of thematic and structural proposals for the night-shift depot fiction. Triaged here so the workable parts are recorded with their reasoning and the rest does not have to be re-argued later.
- Evidence and assessment:
  - **Memo board framing** — presenting the shop as pinned depot memos rather than as cards. Pure naming, no mechanical cost, and consistent with the results screen, which already prints a dot-matrix manifest with a rubber-stamp verdict. Free.
  - **Shift reports and performance badges** — end-of-run summaries styled as workplace evaluations, with efficiency ratings and incident counts. This *extends what already exists*: `RunSummary.verdict` already stamps `PROBATIONARY`, `CLEARED` or `EMPLOYEE OF THE SHIFT`. Cheapest good idea in the batch.
  - **Daily fixed-seed challenge — local only.** Every run is already fully seeded, so a seed derived from the date costs nothing. **The global leaderboard half is rejected**: the scope ceiling allows zero backend calls and v1 excludes online leaderboards.
  - **Quota contracts** — opt into sorting a target clean for a large payout, forfeiting the segment's pay on failure. Strong, and worth noting that it is **the already-approved double-or-nothing wager relocated from the results screen into the run**, not a new system.
  - **Hazardous cargo** — packages valid in two chutes and forbidden in a third. Still one tap on the front-most package, still deterministic, and it flips the task from finding the right answer to avoiding the wrong one, which is different cognitive work. Fits the existing `RoutingRule` model.
  - **Scanner reveal** — package labels hidden until they pass a reveal point near the sort line. The sharpest of the batch: it compresses the *effective* read window without touching the read window itself, and it interacts directly with clutch saves. Expressible as a single progress threshold.
  - **Visual workstation degradation** — flickering lights and steam tracking chaos and belt speed. Passes the play-field effects test, since it carries information about the run's state rather than decorating it. But it is exactly the particle work flagged as the mid-range frame-rate trap against §11.13's 60fps target, and assets must be procedural under the zero-art ceiling. **Design freely, measure on a device before building.**
  - **Label rotation** — rejected on inspection rather than on principle. The shape vocabulary is circle, triangle and square: a rotated circle is identical, and a square rotated by ninety degrees is identical. The mechanic only reads on one shape in three, so it would need a different shape set to earn its place.
- Options considered: adopt wholesale; triage; reject wholesale.
- Decision: none yet. Recommendation is to take the three free presentation wins, and to treat quota contracts, hazardous cargo and the scanner reveal as the three mechanics worth designing properly.
- Consequences: None of this is scheduled. The approved-but-unbuilt queue already holds the endless shop, `PRIORITY`, level 10, the wager and the audio pipeline, and no human has yet played more than a few minutes of the game.
- Owner/gate: human — Gate 4.

### 2026-08-17 — Four proposals rejected against standing decisions

- Status: rejected (human gate, 2026-08-17)
- Context: Recorded so these do not return in a month without the counter-argument attached. Each conflicts with a decision already approved, rather than merely being unappealing.
- Evidence:
  - **VIP packages that break queue order.** *Control model: tap-the-bin with front-most active package* was approved at Gate 2, and free selection of any visible package was explicitly rejected there. The engine can only route the front-most package, so a VIP that must be sorted first while not being front-most is unroutable. This requires reopening the control model, not adding a card.
  - **Fragile heavyweights needing a hold-and-drag or double-tap.** `docs/product-brief.md` rejected drag routing by name — "precision dragging of a moving object... hostile to one-thumb portrait play" — and `docs/design-system.md` states that unusual transitions are acceptable but unusual core controls are not. Double-tap is more defensible than drag but is still a second control verb in a deliberately one-verb game.
  - **Strobe and blackout phases.** `docs/design-system.md` requires avoiding rapid flashing. That is an accessibility rule, not a preference. A slow dim would be arguable; pulsing or flickering light as a mechanic is not.
  - **A permanent unlock tree spending pay across runs.** Rejected twice already — under *Pay and powerups* and again under the endless shop decision. `CLAUDE.md` forbids that machinery until repeat play has been demonstrated by human testing, v1 excludes complex inventory, and persistent purchased power makes runs incomparable, which directly undermines the pitch of beating your own best run.
- Options considered: adopt each; reject each with the standing decision cited.
- Decision: All four rejected. Any of them can return, but only by reopening the specific approved decision it contradicts.
- Consequences: The control model, the one-verb input rule, the no-flashing accessibility rule and the no-persistence rule are all load-bearing for more than these four ideas, so reopening any of them is a larger decision than the feature that prompted it.
- Owner/gate: human — Gate 4.
