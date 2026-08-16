# Sort Rush — Project Constitution

## Mission

Build a tiny, highly replayable Android casual game: a one-thumb parcel-sorting game with a glitchy counterculture identity. The first product milestone is a playable Flutter + Flame prototype, followed by a Google Play internal test.

## Non-negotiables

- Stack: Dart, Flutter, Flame; Android-first; portrait; offline-first.
- Scope: one solo developer, two-day prototype, one-week playable build.
- Core loop: observe package → choose destination → tap → receive feedback → manage pressure → repeat.
- Gameplay clarity beats visual novelty. Anti-mainstream expression belongs around the active play field unless usability remains excellent.
- No accounts, backend, multiplayer, monetization, energy, loot boxes, or online content in v1.
- Use procedural shapes, typography, particles, and simple sound before adding an asset pipeline.
- Gameplay randomness must be seedable. Difficulty must be data-driven.
- Flutter widgets own navigation, overlays, settings, and result screens. Flame owns the active loop and gameplay components.

## Agent operating model

Agents are human-gated. They may inspect, research, propose, implement an approved slice, test, and report. They must pause at milestone gates and must never silently change the design.

Every task report must include: current state, goal, evidence, proposed action, files to change, tests to run, risks, explicit non-goals, approval status, and decision-log update.

Read the relevant files before acting:

- Product/design: `@docs/product-brief.md`, `@docs/design-system.md`, `@docs/level-spec.md`
- Quality: `@docs/testing-strategy.md`
- History: `@docs/decision-log.md`

## Required behavior

- Research current facts and cite sources when the task depends on changing external requirements.
- Prefer the smallest change that advances the approved milestone.
- Add or update tests with behavior changes.
- Never hide a failing test, crash, analyzer warning, or unresolved design contradiction.
- Never modify unrelated systems.
- Do not add monetization until repeat play has been demonstrated by human testing.
- Do not claim a milestone is complete without its acceptance criteria and evidence.

## Milestones

1. Concept: pitch, core loop, target player, risks, scope ceiling.
2. Design: states, UI/UX, rules, onboarding, endless curve, technical handoff.
3. Prototype: one complete run, scoring, combo, game over, restart, no P0/P1 bugs.
4. Vertical slice: onboarding, endless mode, persistence, feedback, device test.
5. Internal test: signed AAB, listing basics, tester channel, release evidence.

## Expected commands

Once Flutter exists, keep these commands working and document any changes:

```text
flutter pub get
flutter analyze
flutter test
flutter run
flutter build appbundle --release
```

## Decision discipline

Record meaningful decisions in `docs/decision-log.md`. A proposal is not an approved decision until the human gate is marked approved. If evidence invalidates a decision, add a new entry; do not rewrite history.
