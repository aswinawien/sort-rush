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

- Status: proposed
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

- Status: proposed
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

- Status: proposed
- Context: Product-brief risk 4 is hidden coupling from AI-generated code. Testing-strategy layer 1 requires unit-testing scoring, combo, difficulty, seed replay, and state transitions without a game loop.
- Evidence: Those tests are only possible if the logic has no engine dependency; the constitution also requires seedable randomness and data-driven difficulty.
- Options considered: (a) logic inside Flame components; (b) pure-Dart core with Flame as a rendering and input shell.
- Decision: Option (b). Scoring, combo, difficulty curve, routing rules, seeded RNG, and the run state machine import neither `package:flame` nor `package:flutter`. One seeded `Random` is owned by the run and injected; no other `Random()` call exists.
- Consequences: A guard test asserts the core has no engine imports. Same seed plus same input timeline must reproduce a run exactly.
- Owner/gate: human — Gate 2.

### 2026-08-16 — Fairness floors for difficulty scaling

- Status: proposed
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

- Status: proposed
- Context: Three implementation choices depart from the Flutter/Flame mapping table in `docs/design-spec.md` §9. Recording them rather than letting the code and the spec drift apart silently.
- Evidence: All three were made while implementing the Milestone 3 slice; the analyzer and 63 tests pass with them in place.
- Options considered: follow the mapping literally, or deviate and record.
- Decision: (a) `PackageComponent` is a painter called by `BeltComponent`, not one component per package — mirroring engine state into component lifecycles each frame adds a desync the player would see, for no visual gain. (b) Pause is a Flutter `Stack` rather than a Flame overlay, because pause must reach `Navigator` for "quit to home". (c) Results shows `SHIFT COMPLETE` on a pass and `SHIFT ENDED` on a fail; the manifest was specified for endless run stats and had no pass/fail concept.
- Consequences: §9's component inventory no longer matches the code exactly. (c) is an interim answer to open decision §12.6 and still needs a design pass.
- Owner/gate: human — Gate 3.

### 2026-08-16 — Android target API level for the Play release

- Status: proposed
- Context: Milestone 5 is a Google Play internal test. Target API configuration is cheap to set correctly at project creation and expensive to retrofit.
- Evidence: Google Play requires new apps and updates to target Android 16 (API 36) or higher from 31 August 2026, with extensions available to 1 November 2026. Existing apps must target API 35 or higher to stay available to new users on newer devices. Source: Play Console Help, "Target API level requirements for Google Play apps", retrieved 2026-08-16.
- Options considered: (a) set `targetSdk 36` at project creation; (b) accept the Flutter template default and fix before release.
- Decision: Set `compileSdk`/`targetSdk` to 36 when the Flutter project is created, and verify a release `appbundle` builds before Milestone 4 closes.
- Consequences: Removes a release-blocking surprise. May surface API-36 behavior changes early, which is the intent.
- Owner/gate: human — Gate 2.
- Verified 2026-08-16: no code change was needed. Flutter 3.47.0 already defaults `targetSdkVersion` to 36 (`FlutterExtension.kt:34`), and the generated `android/app/build.gradle.kts` reads `flutter.targetSdkVersion`, so the project already meets the 31 August 2026 requirement. Left on the Flutter default rather than hardcoded, so it tracks future SDK bumps; revisit if the default ever drops below the Play floor. The release `appbundle` build is still unverified — no Android SDK is installed on this machine.
