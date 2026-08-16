# Product Brief

## Working title

Sort Rush

## One-line pitch

Sort packages at an increasingly unreasonable speed, preserve your combo, and prove you can beat your own best run.

## Player promise

The player should understand the first action in seconds and feel a sharp, readable rush from accurate sorting.

## Target player

People who enjoy short one-thumb puzzle, timing, sorting, and score-chasing sessions. Assume the player may only give the game 30 seconds initially.

## Core loop

Observe a package → identify its destination → tap the bin → receive immediate feedback → manage speed and active packages → chase combo and score → restart after failure.

## Modes

- Curated onboarding: 8–12 short levels, each teaching one pressure.
- Endless: one deterministic score chase unlocked after onboarding.

## v1 exclusions

No accounts, backend, multiplayer, online leaderboard, ads, premium currency, energy, story, complex inventory, procedural level generator, or custom illustration dependency.

## Risks

1. Sorting may feel like a tapping demo. Mitigation: combo tension, active-package pressure, readable near misses, and curated escalation.
2. Visual experimentation may reduce clarity. Mitigation: novelty budget and UX review.
3. Endless mode may become unfair. Mitigation: deterministic difficulty data and seeded tests.
4. AI-generated code may create hidden coupling. Mitigation: small interfaces, analyzer/tests, and human gates.

## Discarded alternatives

Recorded for Gate 1. Each was considered seriously and rejected on a stated ground.

1. **Drag-and-drop routing.** Player drags each package into a bin. Rejected: precision dragging of a moving object contradicts "destination controls must be large and forgiving" and is hostile to one-thumb portrait play. It also makes touch-target acceptance criteria nearly untestable.
2. **Grid/tile sorting.** Player matches packages on a board rather than a belt. Rejected: removes the "rush" — the pressure becomes spatial puzzle-solving, not timed triage — and lands in the most crowded corner of the casual market, where our differentiation is weakest.
3. **Multiple simultaneous belts.** Two or three parallel lanes feeding separate bin sets. Rejected: splits attention across the screen width, breaks thumb ergonomics in portrait, and inflates prototype scope well past the two-day ceiling for a pressure we can already produce with spawn rate.

## Scope ceiling

Hard limits for v1. Exceeding any of these requires a new decision-log entry and a human gate.

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
| Bundled art assets | 0 for prototype; procedural shapes and type only |

## Prototype numerical assumptions

Starting values for the prototype, to be replaced by measured values after human device testing. Rationale is recorded in `docs/level-spec.md`.

- Read window (spawn to sort line) starts at 4.0s and floors at **1.2s**.
- Spawn interval starts at 2.6s and floors at **0.65s**.
- Maximum active packages on the belt: 1 → 5.
- Mistake limit: 3.
- Base score per correct sort: 10, multiplied by combo tier.
- Combo tier advances every 5 consecutive correct sorts, capped at x5.

The 1.2s read-window floor and 0.65s spawn floor are the fairness limits: below them, a first-time player cannot reliably read two attributes and act. These two numbers are the primary fairness contract and should not be lowered without device-test evidence.

## Gate 1 acceptance

- [ ] Pitch and target player are approved.
- [x] Core loop can be explained in one sentence.
- [x] Three discarded alternatives are recorded.
- [x] Scope ceiling is explicit.

Status: **awaiting human approval.** Unchecked items require the human gate, not agent assertion.
