# QA workflow — profiler and memo preview

Development-only tooling for testing the visual layers. None of it exists in a
release build; see "Release absence" below for how that is verified.

## Launching the lab

```
flutter run -t lib/dev/dev_lab.dart -d chrome      # desktop review
flutter run -t lib/dev/dev_lab.dart -d <device>    # real device
```

A scripted play harness lives alongside it for capture work:

```
flutter run -t lib/dev/dev_autoplay.dart -d chrome
```

## Controls

| Key | Action |
|---|---|
| F3 | Toggle profiler overlay |
| F4 | Cycle Standard / Immersive Neon |
| F5 | Next memo variant |
| F6 | Replay current memo |
| F7 | Toggle optional particles and trails |
| F8 | Preview reduce motion (does not touch the saved setting) |
| F9 | Print a QA capture to the console |
| F10 | Reset measurements |

On-screen chips duplicate every key, so the lab is usable on a touch device
where there is no keyboard.

## Reading the profiler

Pinned to the middle of the left edge. That strip is the one region of the play
field nothing gameplay-critical occupies — the score sits in the top 14%, the
mistake pips top-right, packages travel down the centre, chutes own the bottom
quarter.

Frame numbers are coloured by grade:

```
GOOD       under 16.67ms      acid
WARNING    16.67 - 25ms       amber
BAD        above 25ms         warn
```

`worst` is the worst frame since the last reset, not the worst still inside the
rolling window — the hitch you are hunting has usually already scrolled past.

Frame time is measured as `FrameTiming.totalSpan`, which includes rasterisation.
Build time alone would hide the GPU cost, which is the thing that has never been
measured on real hardware.

## The capture

F9 prints:

```
Visual style: Immersive Neon
Memo profile: Corruption Warning
Average frame: 12.4ms
Worst frame: 19.8ms
Peak particles: 18
Peak trails: 3
Reduce motion: false
```

## Test matrix

Every memo variant, in all four combinations:

| | Standard | Immersive Neon |
|---|---|---|
| Reduce motion off | ✅ | ✅ |
| Reduce motion on | ✅ | ✅ |

Variants: Normal · New Rule · Corruption Warning · Shop · Shift Results ·
Shift Transition.

Record per run: build, device, memo profile, visual style, reduce-motion state,
average frame, worst frame, peak particles, peak trails, animation duration,
whether it was interrupted or skipped, any stutter/clipping/overlap/unreadable
text, and a result of PASS / CONCERN / FAIL.

## Readability and fairness checks

These are the checks that outrank performance. A fast build that fails one of
these is not shippable.

- Package silhouettes stay immediately identifiable.
- Fill patterns stay visible; nothing fuses hatch and dotted.
- The acid active marker is never hidden or competed with.
- Corrupted packages stay visually distinct from clean ones — and carry no
  warning colour, which is a mistake cue, not a damage cue.
- Trails never resemble a circle, triangle, square, or a fill pattern.
- No effect covers another routable package.
- The correct-sort burst fires only after its package has left the belt.
- No per-frame silhouette flicker anywhere.
- No effect creates a false gameplay cue.
- Zine and CRT treatment never washes out paper text or controls.

## Performance concerns

Raise a CONCERN when:

- Immersive Neon repeatedly exceeds 16.67ms on the target device.
- Any effect causes visible stutter.
- Particle or trail counts grow without returning to baseline.
- Repeated memo transitions increase active object counts or memory.
- Effects keep running after their event ends.
- Any repeated frame exceeds 25ms without a clear cause.

`Immersive Neon` stays off by default until real-device QA confirms both
performance and readability. Desktop results do not qualify.

## Release absence

The lab and the profiler live in `lib/dev/` and nothing in the shipped app
imports them. **`lib/dev/dev_stats.dart` is the exception** — it is imported by
`lib/game/components/bin_component.dart` and `lib/ui/memo/memo_transition.dart`
so effect counts can be tracked. Its call sites are guarded by
`const kDevTools = !kReleaseMode`, which const-folds away in release, but that
is an argument from construction: grepping for `DEV LAB` tests only the lab, not
the counters.

Verify both:

```
flutter build web --release
grep -c "DEV LAB" build/web/main.dart.js        # 0 — the lab
grep -c "Peak particles" build/web/main.dart.js # 0 — the summary
grep -c "activeParticles" build/web/main.dart.js # counters
```
