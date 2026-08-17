#!/usr/bin/env python3
"""Emit docs/depot-record.html from docs/decision-log.md.

One-way. Editing the HTML changes nothing — the log is canonical.
"""

from __future__ import annotations

import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOG = ROOT / "docs" / "decision-log.md"
OUT = ROOT / "docs" / "depot-record.html"

STATUS_RE = re.compile(r"Status:\s*\**(\w+)", re.IGNORECASE)
GATE_RE = re.compile(r"Gate\s+(\d+)", re.IGNORECASE)
HEADING_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})\s+[—–-]\s+(.+)$")
DECISION_RE = re.compile(
    r"^- Decision:\s*(.*?)(?=^- (?:Consequences|Owner/gate|Options|Evidence|Context):|\Z)",
    re.MULTILINE | re.DOTALL,
)

KNOWN = {"approved", "proposed", "rejected", "superseded"}


def parse(text: str) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    for part in re.split(r"^### ", text, flags=re.MULTILINE)[1:]:
        first, _, rest = part.partition("\n")
        match = HEADING_RE.match(first.strip())
        if not match or match.group(2).strip().lower() == "decision title":
            continue
        date, name = match.group(1), match.group(2).strip()
        status_m = STATUS_RE.search(rest)
        status = (status_m.group(1).lower() if status_m else "proposed")
        if status not in KNOWN:
            status = "proposed"
        gate_m = GATE_RE.search(rest)
        gate = f"Gate {gate_m.group(1)}" if gate_m else "—"
        dec_m = DECISION_RE.search(rest)
        decision = " ".join((dec_m.group(1) if dec_m else "").split())
        entries.append(
            {
                "date": date,
                "name": name,
                "status": status,
                "gate": gate,
                "decision": decision,
            }
        )
    return entries


def inline(text: str) -> str:
    escaped = html.escape(text)
    escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", escaped)
    return escaped


def shorten(text: str, limit: int = 220) -> str:
    if len(text) <= limit:
        return text
    return text[: limit - 1].rsplit(" ", 1)[0] + "…"


def row(entry: dict[str, str]) -> str:
    status = entry["status"]
    date = entry["date"][5:]  # MM-DD
    decision = inline(shorten(entry["decision"]))
    return (
        f"<tr class='s-{status}'>"
        f"<td class='dt'>{html.escape(date)}</td>"
        f"<td class='nm'>{inline(entry['name'])}"
        f"<span class='dec'>{decision}</span></td>"
        f"<td><span class='pill p-{status}'>{html.escape(status)}</span></td>"
        f"<td class='gt'>{html.escape(entry['gate'])}</td>"
        f"</tr>"
    )


CSS = """
  /* Light is the printed manifest from the results screen.
     Dark is the play field. The game already owns both surfaces, so the
     two themes are the product's own, not a decoration. Tokens are lifted
     verbatim from lib/ui/theme.dart. */
  :root {
    --ground: #F2EDE3;
    --raised: #EAE3D6;
    --ink: #0D0D0F;
    --body: #26262B;
    --mute: #6E6E76;
    --rule: #CFC7B7;
    --accent: #5E7A00;
    --accent-ink: #0D0D0F;
    --ok: #4E6B2A;
    --wait: #9A6B10;
    --stop: #C0341A;
    --gone: #8A8A92;
    --stamp-bg: rgba(94,122,0,.10);
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --ground: #0D0D0F;
      --raised: #17171B;
      --ink: #F2EDE3;
      --body: #D8D3C8;
      --mute: #6E6E76;
      --rule: #2A2A31;
      --accent: #C6FF00;
      --accent-ink: #0D0D0F;
      --ok: #A9D45A;
      --wait: #E0AE4A;
      --stop: #FF4B26;
      --gone: #6E6E76;
      --stamp-bg: rgba(198,255,0,.10);
    }
  }
  :root[data-theme="dark"] {
    --ground: #0D0D0F;
    --raised: #17171B;
    --ink: #F2EDE3;
    --body: #D8D3C8;
    --mute: #6E6E76;
    --rule: #2A2A31;
    --accent: #C6FF00;
    --accent-ink: #0D0D0F;
    --ok: #A9D45A;
    --wait: #E0AE4A;
    --stop: #FF4B26;
    --gone: #6E6E76;
    --stamp-bg: rgba(198,255,0,.10);
  }

  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: var(--ground);
    color: var(--body);
    font-family: ui-monospace, "SF Mono", "Cascadia Mono", Menlo, Consolas, monospace;
    font-size: 14px;
    line-height: 1.55;
    -webkit-font-smoothing: antialiased;
  }
  .sheet { max-width: 1080px; margin: 0 auto; padding: 0 24px 96px; }

  .perf {
    height: 18px;
    background-image: radial-gradient(circle at 9px 9px, var(--rule) 2.5px, transparent 3px);
    background-size: 18px 18px;
    border-bottom: 1px solid var(--rule);
  }

  header { padding: 44px 0 30px; border-bottom: 2px solid var(--ink); }
  .mast { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; }
  .eyebrow {
    font-size: 11px; letter-spacing: .22em; text-transform: uppercase;
    color: var(--mute); margin: 0 0 14px;
  }
  h1 {
    font-size: clamp(30px, 6vw, 50px); font-weight: 700; letter-spacing: -.02em;
    margin: 0 0 10px; color: var(--ink); text-wrap: balance; line-height: 1.02;
  }
  .lede { margin: 0; max-width: 62ch; color: var(--body); }
  .lede strong { color: var(--ink); }

  .theme {
    flex-shrink: 0;
    font-size: 10px; letter-spacing: .14em; text-transform: uppercase;
    color: var(--mute); background: transparent; border: 1px solid var(--rule);
    padding: 8px 12px; cursor: pointer; font-family: inherit; font-weight: 700;
  }
  .theme:hover { color: var(--ink); border-color: var(--ink); }

  h2 {
    font-size: 12px; letter-spacing: .2em; text-transform: uppercase;
    color: var(--mute); margin: 52px 0 16px; font-weight: 700;
  }

  .board { display: grid; grid-template-columns: repeat(auto-fit, minmax(148px, 1fr)); gap: 1px; background: var(--rule); border: 1px solid var(--rule); }
  .cell { background: var(--ground); padding: 18px 16px; }
  .fig { font-size: 34px; font-weight: 700; color: var(--ink); line-height: 1; font-variant-numeric: tabular-nums; }
  .fig.on { color: var(--accent); }
  .cap { font-size: 11px; letter-spacing: .12em; text-transform: uppercase; color: var(--mute); margin-top: 8px; }

  .note { border-left: 3px solid var(--stop); background: var(--raised); padding: 16px 18px; margin: 0 0 14px; }
  .note h3 { margin: 0 0 6px; font-size: 14px; color: var(--ink); font-weight: 700; }
  .note p { margin: 0; color: var(--body); }
  .note .found { display: block; margin-top: 8px; font-size: 12px; color: var(--mute); }

  .scroller { overflow-x: auto; border: 1px solid var(--rule); }
  table { width: 100%; border-collapse: collapse; min-width: 620px; }
  th {
    text-align: left; font-size: 10px; letter-spacing: .16em; text-transform: uppercase;
    color: var(--mute); font-weight: 700; padding: 11px 14px;
    border-bottom: 1px solid var(--rule); background: var(--raised); position: sticky; top: 0;
  }
  td { padding: 12px 14px; border-bottom: 1px solid var(--rule); vertical-align: top; }
  tr:last-child td { border-bottom: 0; }
  tbody tr { border-left: 3px solid transparent; }
  tbody tr.s-approved { border-left-color: var(--ok); }
  tbody tr.s-proposed { border-left-color: var(--wait); }
  tbody tr.s-rejected { border-left-color: var(--stop); }
  tbody tr.s-superseded { border-left-color: var(--gone); }

  .dt { color: var(--mute); font-variant-numeric: tabular-nums; white-space: nowrap; font-size: 12px; }
  .nm { color: var(--ink); font-weight: 700; max-width: 62ch; }
  .dec { display: block; margin-top: 5px; font-weight: 400; color: var(--body); font-size: 12.5px; }
  .gt { color: var(--mute); white-space: nowrap; font-size: 12px; }

  .pill {
    display: inline-block; font-size: 10px; letter-spacing: .1em; text-transform: uppercase;
    padding: 3px 9px; border: 1px solid currentColor; white-space: nowrap; font-weight: 700;
  }
  .p-approved { color: var(--ok); background: var(--stamp-bg); }
  .p-proposed { color: var(--wait); }
  .p-rejected { color: var(--stop); }
  .p-superseded { color: var(--gone); }

  ul.open { list-style: none; padding: 0; margin: 0; display: grid; gap: 10px; }
  ul.open li { border: 1px solid var(--rule); padding: 14px 16px; background: var(--raised); }
  ul.open b { color: var(--ink); }
  ul.open span { display: block; margin-top: 5px; color: var(--body); font-size: 12.5px; }

  ol.ms, ol.next { list-style: none; padding: 0; margin: 0; display: grid; gap: 10px; }
  ol.ms li, ol.next li {
    border: 1px solid var(--rule); padding: 14px 16px; background: var(--raised);
    display: grid; grid-template-columns: 7.5rem 1fr; gap: 16px; align-items: start;
  }
  @media (max-width: 640px) {
    ol.ms li, ol.next li { grid-template-columns: 1fr; gap: 6px; }
  }
  .tag {
    font-size: 10px; letter-spacing: .14em; text-transform: uppercase; font-weight: 700;
    padding-top: 3px;
  }
  .tag.done { color: var(--ok); }
  .tag.now { color: var(--accent); }
  .tag.later { color: var(--mute); }
  ol.ms b, ol.next b { color: var(--ink); }
  ol.ms p, ol.next p { margin: 4px 0 0; color: var(--body); font-size: 12.5px; }
  ol.next { counter-reset: nxt; }
  ol.next li { grid-template-columns: 2rem 1fr; }
  ol.next li::before {
    counter-increment: nxt; content: counter(nxt);
    font-weight: 700; color: var(--accent); font-size: 18px; line-height: 1.2;
  }
  ol.next li.logged::before { color: var(--ok); }
  ol.next li.logged b { color: var(--mute); }

  footer { margin-top: 56px; padding-top: 22px; border-top: 2px solid var(--ink); color: var(--mute); font-size: 12px; }
  footer strong { color: var(--ink); }
  a { color: var(--accent); text-decoration-thickness: 1px; text-underline-offset: 3px; }
  a:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; }
  code { font-family: inherit; font-size: 0.92em; }
"""


def render(entries: list[dict[str, str]]) -> str:
    counts = {k: 0 for k in KNOWN}
    for entry in entries:
        counts[entry["status"]] += 1
    proposed = counts["proposed"]
    newest_first = list(reversed(entries))
    rows = "\n".join(row(e) for e in newest_first)
    n = len(entries)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Depot 7 Shift Record</title>
  <style>{CSS}
  </style>
</head>
<body>
<div class="perf"></div>
<div class="sheet">

<header>
  <div class="mast">
    <div>
      <p class="eyebrow">Depot 7 · Night Shift · Generated from the repository</p>
      <h1>Shift Record</h1>
    </div>
    <button type="button" class="theme" id="theme" aria-label="Toggle paper and ink">INK</button>
  </div>
  <p class="lede">A one-thumb parcel-sorting game in Flutter and Flame. <strong>Gate 4 awaiting a ruling</strong> — onboarding and endless evidenced; persistence unbuilt; audio blocked; floors untimed. Packet: <code>docs/milestone-4-gate.md</code>.</p>
</header>

<h2>Status board</h2>
<div class="board">
  <div class="cell"><div class="fig on">265</div><div class="cap">Tests passing</div></div>
  <div class="cell"><div class="fig">10<span style="color:var(--mute)">/10</span></div><div class="cap">Curated shifts</div></div>
  <div class="cell"><div class="fig">{n}</div><div class="cap">Decisions logged</div></div>
  <div class="cell"><div class="fig">{proposed}</div><div class="cap">Awaiting a gate</div></div>
  <div class="cell"><div class="fig on">1</div><div class="cap">Humans who played</div></div>
</div>

<h2>The ladder</h2>
<ol class="ms">
  <li><span class="tag done">Closed</span><div><b>1 · Concept</b><p>Pitch, core loop, target player, risks, scope ceiling. Gate 1.</p></div></li>
  <li><span class="tag done">Closed</span><div><b>2 · Design</b><p>States, UI/UX, rules, onboarding, endless curve, technical handoff. Gate 2.</p></div></li>
  <li><span class="tag done">Closed</span><div><b>3 · Prototype</b><p>One complete run, scoring, combo, game over, restart. Accepted 2026-08-16. “No P0/P1” was accepted on automated tests alone — that debt is Milestone 4’s.</p></div></li>
  <li><span class="tag now">You are here</span><div><b>4 · Vertical slice</b><p>Onboarding 1–10 and endless <strong>ship</strong>. First human play logged 2026-08-17 (qualitative: looks good). Still open: persistence (best run), feedback (audio), and a device test that measures the fairness floors. Settings is budgeted and unbuilt.</p></div></li>
  <li><span class="tag later">Next gate</span><div><b>5 · Internal test</b><p>Signed AAB already builds. Still needs store listing basics, an internal tester channel on Play, and release evidence. Do not start this until Gate 4 closes.</p></div></li>
</ol>

<h2>Playtests</h2>
<div class="note">
  <h3>2026-08-17 · developer · web</h3>
  <p>One human played. Verdict: looks good. No P0/P1 named. The questionnaire in <code>docs/testing-strategy.md</code> was not filled. Fairness floors (1.20s / 0.65s) were not timed. This closes the zero-player gap. It does not close Gate 4, and it is not the device test.</p>
  <span class="found">Logged from the human gate, not from a scripted scenario.</span>
</div>

<h2>What to do next</h2>
<ol class="next">
  <li><div><b>Rule Gate 4.</b><p>Read <code>docs/milestone-4-gate.md</code>. The recommendation is <strong>hold</strong>. Accepting would close two of five criteria and leave the pitch — beat your own best run — with nowhere to live in Milestone 5.</p></div></li>
  <li class="logged"><div><b>Play it yourself.</b><p>Logged 2026-08-17. Developer play, qualitative pass. Questionnaire unanswered. Floors unmeasured.</p></div></li>
  <li><div><b>Persistence — beat your own best run.</b><p>The pitch is a personal best and nothing stores one. <code>shared_preferences</code> is already in the package budget. High-score (and malformed-save) tests are required in <code>docs/testing-strategy.md</code>. Unlock-gating endless behind onboarding is still undecided — do not invent that. Do not start this slice until the gate is ruled.</p></div></li>
  <li><div><b>Relaunch.</b><p>Backgrounding already holds the belt and is tested. A killed process restores nothing, because nothing is saved. This rides with persistence.</p></div></li>
  <li><div><b>Audio, only after Suno terms are recorded.</b><p>Approved at Gate 3. Blocked until commercial-use terms for the Play release are written into the decision log. Then: asset pipeline, pressure-band crossfades, a mute that leaves the game fully playable. Prompts live in <code>docs/audio-brief.md</code>.</p></div></li>
  <li><div><b>A device playtest that counts.</b><p>Emulator smoke found three P1s. That is not the fairness test. Sit with the questionnaire in <code>docs/testing-strategy.md</code>, keep a seed, and treat a first-time player’s 1.20s / 0.65s as the thing being measured. Settings (sound-off, skip tutorial) can ride with this if you want the fourth screen.</p></div></li>
  <li><div><b>Close Gate 4, then Milestone 5.</b><p>Listing copy, device screenshots (not web captures), content rating, Play internal-test track, signed AAB already verified. Quota contracts, hazardous cargo and the scanner stay designed-not-built until they get their own entries.</p></div></li>
</ol>

<h2>Every P1 was found by looking, not by testing</h2>
<div class="note">
  <h3>The HUD drew underneath the Android status bar</h3>
  <p>Mistake pips — the player's life counter — rendered on top of the signal and battery icons. The Flame canvas filled the physical screen while only the Flutter pause button sat in a <code>SafeArea</code>.</p>
  <span class="found">Found on the first run on an emulator, minutes after the toolchain came up.</span>
</div>
<div class="note">
  <h3>Compound chutes rendered identically</h3>
  <p>The bin painter drew the silhouette and returned, so a chute carrying both a shape and a pattern never drew the pattern. Levels 8, 9 and endless shipped with two chutes impossible to tell apart while the routing rule distinguished them by hue.</p>
  <span class="found">Found by eye in a screenshot, against 211 passing tests.</span>
</div>
<div class="note">
  <h3>The <code>DAMAGED</code> telegraph was never drawn</h3>
  <p>Nothing read <code>isUnstable</code>, so a corrupting package looked exactly like a clean one until it morphed — while a code comment asserted the opposite. The mechanic rests entirely on the player seeing the corruption and choosing to wait, so the shipped behaviour was the silent version the gate had rejected.</p>
  <span class="found">Found by asking where the glitch effects were.</span>
</div>

<h2>Approved, not yet built</h2>
<ul class="open">
  <li><b>Audio</b><span>Approved as generated music plus an asset pipeline. Blocked until Suno's commercial-use terms are verified against the Play release and recorded in the decision log. Sound-off play must remain complete.</span></li>
  <li><b>Quota contracts, hazardous cargo, scanner reveal</b><span>Designed in the depot-fiction triage. Each needs its own entry before code.</span></li>
</ul>

<h2>Decision ledger</h2>
<div class="scroller">
<table>
  <thead><tr><th>Date</th><th>Decision</th><th>Status</th><th>Gate</th></tr></thead>
  <tbody>
{rows}
  </tbody>
</table>
</div>

<footer>
  <p><strong>The repository is canonical.</strong> This page is generated one-way from <code>docs/decision-log.md</code> by <code>tool/generate_depot_record.py</code>. Editing it changes nothing — Claude Code, Cursor and Codex all read the repo.</p>
  <p style="margin-top:10px">The fairness floors — a <strong>1.20s</strong> read window and a <strong>0.65s</strong> spawn interval — are derived from published reaction-time ranges and have <strong>never been measured on a real player</strong>. Every number in the level tables is a first-pass guess awaiting a device test. <a href="https://github.com/aswinawien/sort-rush">github.com/aswinawien/sort-rush</a></p>
</footer>

</div>
<script>
(function () {{
  var root = document.documentElement;
  var btn = document.getElementById("theme");
  var saved = localStorage.getItem("depot-theme");
  if (saved === "dark" || saved === "light") root.setAttribute("data-theme", saved);
  function label() {{
    var dark = root.getAttribute("data-theme") === "dark" ||
      (!root.getAttribute("data-theme") && matchMedia("(prefers-color-scheme: dark)").matches);
    btn.textContent = dark ? "PAPER" : "INK";
  }}
  label();
  btn.addEventListener("click", function () {{
    var dark = root.getAttribute("data-theme") === "dark" ||
      (!root.getAttribute("data-theme") && matchMedia("(prefers-color-scheme: dark)").matches);
    var next = dark ? "light" : "dark";
    root.setAttribute("data-theme", next);
    localStorage.setItem("depot-theme", next);
    label();
  }});
}})();
</script>
</body>
</html>
"""


def main() -> None:
    entries = parse(LOG.read_text(encoding="utf-8"))
    if not entries:
        raise SystemExit("no decisions parsed from docs/decision-log.md")
    OUT.write_text(render(entries), encoding="utf-8")
    proposed = sum(1 for e in entries if e["status"] == "proposed")
    print(f"Wrote {OUT.relative_to(ROOT)} — {len(entries)} decisions, {proposed} proposed")


if __name__ == "__main__":
    main()
