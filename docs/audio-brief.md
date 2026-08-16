# Audio Brief

Production material for generating the soundtrack. **This is not a decision.** The decision it serves — *Audio direction and asset pipeline* in `docs/decision-log.md` — was approved at Gate 3 on 2026-08-16, so audio is now in scope for Milestone 4.

Two conditions from that decision must be met before any generated audio ships: Suno's commercial-use terms verified against the intended Google Play release and the finding recorded in the decision log, and `pubspec.yaml`'s no-asset-pipeline declaration amended rather than worked around.

Written for Suno. Use the **Instrumental** toggle and paste the prompt into *Style of Music*. If the style field truncates, the first sentence carries the essential direction and the rest can be trimmed from the end.

## Direction

The identity in `docs/design-system.md` is *a strange independent zine that learned to run a very precise arcade machine*. Translated to sound:

> **The wobble lives in the texture. The grid stays machine-perfect.**

Tape warble, fluorescent buzz, detuned stabs, cassette wow — over a rhythm section that never drifts. That is the design system's 20% experimentation / 80% clarity novelty budget expressed as a mix decision. If the drums swing or drag, it is wrong.

Instrument from the depot fiction rather than from a synth preset list: conveyor motor hum as bassline, metal stamp thud as kick, barcode beeps, tape splice clicks, distant PA reverb, fluorescent hum.

## Conventions

- **Key:** F minor for levels 1–9 and endless, so the game coheres as one object. Level 10 breaks to F Phrygian deliberately — see below.
- **No vocals**, anywhere. This is a game about reading things quickly.
- **Loopable**, no intro or outro. Levels run 30–90 seconds, so a ~60 second loop covers nearly all of them.
- **Tempo may change per level.** Each curated level is a self-contained session with a briefing screen either side, so there is no continuous transition to preserve. The crossfade constraint applies only inside endless, where pressure rises continuously.
- **Spawn intervals are not quantised to the beat**, by decision. The approved values are not harmonically related and forcing them onto a grid would flatten a tuned difficulty curve. Music sits under the game; it does not drive it.

## Level tracks

Prompts are written against the *intended feeling* column in `docs/level-spec.md`, which is a better music brief than the difficulty numbers are.

| Level | Teaching objective | Intended feeling | Tempo |
|---|---|---|---|
| 1 | Match one package type | "Oh, that's it." | 92 |
| 2 | Understand three bins | Orientation | 92 |
| 3 | Recognize two package colors | First real reading | 100 |
| 4 | Recognize three package colors | Mild pressure | 100 |
| 5 | Understand combo scoring | Greed | 104 |
| 6 | Manage two active packages | Crowding | 108 |
| 7 | Recover from a near miss | Relief | 108 |
| 8 | Recognize shape plus color | Concentration | 108 |
| 9 | Combine speed and queue pressure | Flow or flood | 116 |
| 10 | Demonstrate mastery | Competence | 116 |

### L1 — INDUCTION

Unfailable by design, and the first thirty seconds a player ever hears. Welcoming and nearly empty.

> Minimal industrial dub techno instrumental, 92 BPM, F minor. Soft conveyor motor hum as bassline, one muted metal stamp on the beat, tape hiss. Almost no melody, lots of space. Calm, curious, welcoming. Perfectly quantized drums, cassette wow on the texture only. No vocals, loopable, no intro or outro.

### L2 — THREE CHUTES

> Minimal industrial dub techno instrumental, 92 BPM, F minor. Conveyor hum bass, stamp thud kick, soft closed hats, one detuned Rhodes chord repeating. Orderly and instructive, gently mechanical. Quantized drums, tape warble on the pads. No vocals, loopable.

### L3 — RELABELLED

Shape stops mattering and pattern takes over. The ground shifts under the player.

> Minimal industrial techno instrumental, 100 BPM, F minor. Conveyor hum bass, stamp kick, brushed metal hats, a detuned Rhodes motif that keeps resolving to the wrong note. Unsettled but controlled — something has quietly changed. Quantized drums, heavy tape flutter. No vocals, loopable.

### L4 — Three colours

> Minimal industrial techno instrumental, 100 BPM, F minor. Driving conveyor bassline, stamp kick with light swing, ticking hi-hats, cold sustained pad. Focused, mildly urgent, nothing dramatic. Machine-tight rhythm, fluorescent hum underneath. No vocals, loopable.

### L5 — Combo scoring

Should tempt the player into rushing, because rushing is how the streak breaks.

> Minimal industrial techno instrumental, 104 BPM, F minor. Rolling bassline, stamp kick, bright barcode-beep arpeggio that climbs and resets. Tempting, moreish, slightly greedy. Machine-tight drums, tape saturation. No vocals, loopable.

### L6 — Two active packages

> Industrial techno instrumental, 108 BPM, F minor. Dense layered percussion, conveyor bass doubled an octave down, overlapping metallic ticks crowding the stereo field. Busy and claustrophobic but never sloppy. Quantized, dry, close-mic'd. No vocals, loopable.

### L7 — Near-miss recovery

> Industrial techno instrumental, 108 BPM, F minor. Tense filtered bassline, sparse stamp kick, rising noise sweep resolving into a warm sustained chord. Anxious then relieved, breathing in and out. Machine-tight drums, tape stop artifacts. No vocals, loopable.

### L8 — Shape plus colour

> Industrial techno instrumental, 108 BPM, F minor. Two interlocking percussion patterns in counterpoint, restrained bassline, no melody at all. Cold, analytical, absorbing. Very dry, very precise, faint fluorescent buzz. No vocals, loopable.

### L9 — Speed and queue

> Driving industrial techno instrumental, 116 BPM, F minor. Relentless conveyor bassline, insistent stamp kick, fast closed hats, distorted acid line surfacing and submerging. Propulsive, right on the edge of too much. Machine-tight, saturated. No vocals, loopable.

### L10 — Mastery and the `PRIORITY` override

**The one deliberate break in the key, and the reason the other nine hold it.** Level 10 is where a stamp first outranks the base rule and the reflex answer becomes a misroute — the mechanic `docs/design-spec.md` §2 calls the most important in the design. Nine levels establish a tonal home so this one can leave it. The music should tell the player the rules changed slightly before they consciously notice.

> Industrial techno instrumental, 116 BPM, F Phrygian. Menacing detuned bassline, hard stamp kick, distorted acid lead, sustained air-raid tone. Authoritative and slightly wrong, like the rules just changed. Machine-tight drums, heavy tape distortion. No vocals, loopable.

## Endless

Two tracks at the same tempo and key, crossfaded by pressure index `P`. This is the one place where continuous transition matters, which is why they must share tempo and key exactly.

**Base** — low `P`:

> Minimal industrial techno instrumental, 104 BPM, F minor. Conveyor hum bass, stamp kick, sparse hats, one cold pad. Patient, hypnotic, endless. Deliberately unfinished, room for more layers. Machine-tight, dry. No vocals, seamless loop.

**High pressure** — high `P`:

> Industrial techno instrumental, 104 BPM, F minor. Distorted acid bassline, doubled percussion, fluorescent buzz drone, rising filtered noise, metallic clangs. Relentless and overloaded but rhythmically exact. Machine-tight, heavily saturated. No vocals, seamless loop.

## Non-gameplay

**Home** — the zine treatment, where the novelty budget rises to 60%.

> Lo-fi industrial ambient, 80 BPM, F minor. Warped cassette pad, distant factory PA reverb, fluorescent hum, occasional tape splice click. Handmade, zine-like, slightly broken. Minimal or no drums. No vocals.

**Results sting** — a one-shot, not a loop. The manifest prints like a dot-matrix printer.

> 8-second dot-matrix printer sting. Mechanical paper feed rhythm, one warm synth chord resolving, tape stop at the end. No vocals.

## Production notes

**Suno does not produce seamless loops.** Generate longer than needed, trim to a bar boundary, and crossfade roughly one second at the seam.

**Budget.** Twelve tracks is roughly 10–12MB in the release AAB. Not fatal, but material for a game whose scope ceiling specifies zero bundled art assets. If size becomes a problem, collapse to four tracks by tempo band — 92 (L1–2), 100–104 (L3–5), 108 (L6–8), 116 (L9–10) — plus the two endless tracks. That costs per-level character and keeps the pressure arc.

**Format.** `audioplayers` is already inside the three-package runtime budget. Prefer OGG for size on Android.

## Constraints that are not negotiable

- **Sound-off play must work.** `docs/design-system.md` requires it. No gameplay information may be carried by audio alone — music is atmosphere, never a cue.
- **Suno's commercial-use terms must be verified** against the intended Google Play release, and the finding recorded in `docs/decision-log.md`, before any generated audio ships.
- **`pubspec.yaml` currently declares no asset pipeline.** That line must be amended as part of approving the audio decision, not quietly worked around.
