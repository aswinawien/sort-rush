# Testing Strategy

## Layers

1. Pure unit tests: scoring, combo, difficulty, seed replay, state transitions.
2. Component tests: spawning, movement, sorting, timeout, pause/resume.
3. Flutter tests: overlays, navigation, settings, persistence boundaries.
4. Scripted scenarios: deterministic play sequences and edge cases.
5. Human device tests: clarity, fairness, comfort, audio, performance.

## Required scenarios

First launch; tutorial; correct sort; wrong sort; combo increase/break; maximum mistakes; timeout; pause/resume; restart; backgrounding; relaunch; high-score persistence; unlock persistence; sound disabled; small/large screens; text scaling; orientation; rapid taps; bin boundaries; fixed seed; malformed save data.

## Bug format

Every report includes ID, severity, reproduction, expected/actual, device, build, seed/level, evidence, suspected subsystem, smallest fix, and regression test.

P0 = crash/data corruption/impossible launch. P1 = core loop or score broken. P2 = major confusion/progression/obstruction. P3 = polish or rare edge case.

## Human questionnaire

Was the first action obvious? Did it feel fair? Was feedback understandable? Did you want another run? Best moment? Most annoying moment? Did visuals help? Was difficulty smooth? Did it feel distinctive? What should change first?

## Completion rule

No milestone is complete with an unresolved P0/P1 issue or unreported failing check.
