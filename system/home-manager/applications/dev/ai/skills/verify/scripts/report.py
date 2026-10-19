#!/usr/bin/env python3
"""Render a /verify report from JSON to HTML, and open it in the browser.

Usage:
  report.py [--no-open] <dir>/<n>-report.json

Writes <dir>/<n>-report.html next to the JSON, prints its path and the
result line, then opens it in the default browser unless --no-open is given.
Screenshot paths in the JSON are relative to <dir>; every one must exist.
Exits 1 with every problem listed when the JSON breaks a rule, so they can
all be fixed in one pass.

JSON shape (`date` is optional; it defaults to the JSON file's date):

  {
    "goal": "round-avatar",
    "date": "2026-10-19",
    "before": {"ref": "main", "sha": "1a2b3c4", "at": "http://localhost:3001",
               "setup": "pnpm dev --port 3001, DATA_DIR=/tmp/v/before"},
    "after":  {"ref": "feat/round-avatar", "sha": "5d6e7f8", "at": "http://localhost:3002",
               "setup": "pnpm dev --port 3002, DATA_DIR=/tmp/v/after"},
    "notes": ["Uncommitted changes in the checkout were applied to after."],
    "tests": [
      {
        "title": "Profile image is a circle",
        "verdict": "PASS",
        "steps": ["Open the browser", "Click Settings",
                  "Check that the profile image is a circle (it used to be a square)"],
        "before": {"images": ["3/1-before.png"], "note": "Square image, as expected."},
        "after":  {"images": ["3/1-after.png"], "note": "Circle image, as expected.",
                   "text": "optional text dump of the screen"}
      },
      {
        "title": "Admin can reset the image",
        "verdict": "NOT RUN",
        "why": "No admin test account.",
        "steps": ["Log in as an admin", "..."],
        "before": {"images": [], "note": ""},
        "after":  {"images": [], "note": ""}
      }
    ]
  }

Verdicts are PASS, FAIL or NOT RUN. A PASS needs a screenshot on both sides;
FAIL and NOT RUN need a `why`. A side that did not exist before the change
is `"before": null`.
"""

import datetime
import html
import json
import os
import re
import shutil
import subprocess
import sys

VERDICTS = {
    "PASS": ("pass", "✅"),
    "FAIL": ("fail", "❌"),
    "NOT RUN": ("notrun", "⏸️"),
}

STYLE = """
:root {
  color-scheme: light dark;
  --bg: #f7f7f5; --card: #ffffff; --fg: #1d1d1b; --muted: #6b6b66; --line: #e3e3de;
  --code: #efefea;
  --pass: #1f7a3d; --pass-bg: #e3f4e8; --fail: #b3261e; --fail-bg: #fbe5e3;
  --notrun: #8a5a00; --notrun-bg: #fbf0d9;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #161615; --card: #1f1f1d; --fg: #ececea; --muted: #9b9b95; --line: #33332f;
    --code: #2b2b28;
    --pass: #7bd69a; --pass-bg: #183524; --fail: #ff8f86; --fail-bg: #3f1d1a;
    --notrun: #f0c46a; --notrun-bg: #3a2e14;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--bg); color: var(--fg);
  font: 15px/1.55 system-ui, -apple-system, "Segoe UI", sans-serif;
}
main { max-width: 1200px; margin: 0 auto; padding: 32px 16px 64px; }
h1 { font-size: 26px; margin: 0 0 12px; }
h2 { font-size: 19px; margin: 0; }
h3 { font-size: 13px; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); margin: 18px 0 8px; }
a { color: inherit; }
code, pre { font-family: ui-monospace, "JetBrains Mono", Menlo, monospace; font-size: 13px; }
code { background: var(--code); padding: 1px 5px; border-radius: 4px; }
pre { background: var(--code); padding: 10px 12px; border-radius: 6px; overflow-x: auto; white-space: pre-wrap; }
.meta { display: grid; grid-template-columns: max-content 1fr; gap: 4px 16px; color: var(--muted); margin: 0 0 16px; }
.meta dt { font-weight: 600; }
.meta dd { margin: 0; color: var(--fg); overflow-wrap: anywhere; }
.result { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 24px; }
.badge { display: inline-block; padding: 2px 10px; border-radius: 999px; font-weight: 600; font-size: 13px; white-space: nowrap; }
.badge.pass { color: var(--pass); background: var(--pass-bg); }
.badge.fail { color: var(--fail); background: var(--fail-bg); }
.badge.notrun { color: var(--notrun); background: var(--notrun-bg); }
.card { background: var(--card); border: 1px solid var(--line); border-radius: 10px; padding: 20px; margin-bottom: 20px; }
table { border-collapse: collapse; width: 100%; }
th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid var(--line); vertical-align: top; }
th { color: var(--muted); font-weight: 600; font-size: 13px; }
tr:last-child td { border-bottom: 0; }
td:first-child, th:first-child { width: 2.5em; }
td:last-child, th:last-child { width: 1%; white-space: nowrap; }
.test-head { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
.why { margin: 14px 0 0; padding: 10px 12px; border-radius: 6px; }
.why.fail { background: var(--fail-bg); }
.why.notrun { background: var(--notrun-bg); }
ol { margin: 0; padding-left: 22px; }
.sides { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
@media (max-width: 800px) { .sides { grid-template-columns: 1fr; } }
.side { min-width: 0; }
.side img { display: block; width: 100%; height: auto; border: 1px solid var(--line); border-radius: 6px; margin-bottom: 8px; background: var(--code); }
.side .note { margin: 0 0 8px; }
.na { color: var(--muted); font-style: italic; }
"""


def fail(errors):
    """Print every problem with the JSON and exit 1."""
    print("report.py: the report JSON has problems:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    sys.exit(1)


def inline(text):
    """Escape text for HTML and render `backticks` as code."""
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(str(text)))


def as_list(value):
    """Accept a single string or a list of strings."""
    if value is None:
        return []
    return [value] if isinstance(value, str) else list(value)


def check(report, base_dir):
    """Return every rule the report breaks."""
    errors = []
    if not isinstance(report.get("goal"), str) or not report["goal"]:
        errors.append('"goal" is missing')
    for side in ("before", "after"):
        info = report.get(side)
        if not isinstance(info, dict) or not info.get("ref"):
            errors.append(f'"{side}" needs at least a "ref"')
    tests = report.get("tests")
    if not isinstance(tests, list) or not tests:
        errors.append('"tests" must be a non-empty list')
        return errors
    for number, test in enumerate(tests, 1):
        label = f"test {number}"
        if not isinstance(test, dict):
            errors.append(f"{label} is not an object")
            continue
        if not test.get("title"):
            errors.append(f'{label} has no "title"')
        verdict = normalise(test.get("verdict"))
        if verdict not in VERDICTS:
            errors.append(
                f"{label} has verdict {test.get('verdict')!r}; use PASS, FAIL or NOT RUN"
            )
        if not as_list(test.get("steps")):
            errors.append(f'{label} has no "steps"')
        if verdict in ("FAIL", "NOT RUN") and not test.get("why"):
            errors.append(
                f'{label} is {verdict} but has no "why" (what happened instead, or what blocked it)'
            )
        for side in ("before", "after"):
            info = test.get(side)
            if info is None:
                if side == "after":
                    errors.append(f'{label} has no "after"')
                continue
            if not isinstance(info, dict):
                errors.append(f'{label} "{side}" must be an object or null')
                continue
            images = as_list(info.get("images"))
            for image in images:
                if not os.path.isfile(os.path.join(base_dir, image)):
                    errors.append(
                        f"{label} {side} screenshot not found: {image} (paths are relative to {base_dir})"
                    )
            if verdict == "PASS" and not images:
                errors.append(
                    f"{label} is PASS but has no {side} screenshot; no proof, no PASS"
                )
    return errors


def normalise(verdict):
    """Map 'not_run', 'Not Run' and the like to the canonical verdict."""
    if not isinstance(verdict, str):
        return None
    return re.sub(r"[\s_-]+", " ", verdict.strip()).upper()


def result_counts(tests):
    """Count the tests per verdict."""
    counts = {verdict: 0 for verdict in VERDICTS}
    for test in tests:
        counts[normalise(test["verdict"])] += 1
    return counts


def result_line(counts):
    """The one-line summary, e.g. '2 PASS · 1 FAIL · 0 NOT RUN'."""
    return " · ".join(f"{count} {verdict}" for verdict, count in counts.items())


def badge(verdict):
    """A coloured verdict pill."""
    css, icon = VERDICTS[verdict]
    return f'<span class="badge {css}">{icon} {verdict}</span>'


def ref_text(info):
    """'`ref` (sha) at place' for the header."""
    text = f"<code>{html.escape(info['ref'])}</code>"
    if info.get("sha"):
        text += f" ({html.escape(info['sha'])})"
    if info.get("at"):
        text += f" at {inline(info['at'])}"
    return text


def render_side(name, info):
    """One column of the before/after comparison."""
    parts = [f'<div class="side"><h3>{name}</h3>']
    if info is None:
        parts.append('<p class="na">n/a: did not exist before the change.</p>')
    else:
        images = as_list(info.get("images"))
        for image in images:
            src = html.escape(image, quote=True)
            parts.append(
                f'<a href="{src}" target="_blank"><img src="{src}" alt="{name} screenshot"></a>'
            )
        if not images:
            parts.append('<p class="na">No screenshot.</p>')
        if info.get("note"):
            parts.append(f'<p class="note">{inline(info["note"])}</p>')
        if info.get("text"):
            parts.append(f"<pre>{html.escape(info['text'])}</pre>")
    parts.append("</div>")
    return "".join(parts)


def render(report, number):
    """The whole report as an HTML page."""
    tests = report["tests"]
    counts = result_counts(tests)
    goal = html.escape(report["goal"])
    title = f"Verification {number} — {goal}"

    rows = []
    sections = []
    for index, test in enumerate(tests, 1):
        verdict = normalise(test["verdict"])
        name = inline(test["title"])
        rows.append(
            f'<tr><td>{index}</td><td><a href="#test-{index}">{name}</a></td><td>{badge(verdict)}</td></tr>'
        )
        why = ""
        if test.get("why"):
            why = f'<p class="why {VERDICTS[verdict][0]}"><strong>{"What happened" if verdict == "FAIL" else "Why"}:</strong> {inline(test["why"])}</p>'
        steps = "".join(
            f"<li>{inline(step)}</li>" for step in as_list(test.get("steps"))
        )
        sections.append(
            f'<section class="card" id="test-{index}">'
            f'<div class="test-head"><h2>{index}. {name}</h2>{badge(verdict)}</div>'
            f"{why}"
            f"<h3>Steps</h3><ol>{steps}</ol>"
            f'<div class="sides">{render_side("Before", test.get("before"))}{render_side("After", test.get("after"))}</div>'
            f"</section>"
        )

    setup = []
    for side in ("before", "after"):
        if report[side].get("setup"):
            setup.append(
                f"<li><strong>{side.capitalize()}:</strong> {inline(report[side]['setup'])}</li>"
            )
    setup += [f"<li>{inline(note)}</li>" for note in as_list(report.get("notes"))]
    setup_html = (
        f'<section class="card"><h2>Setup</h2><ul>{"".join(setup)}</ul></section>'
        if setup
        else ""
    )

    chips = "".join(
        f'<span class="badge {VERDICTS[verdict][0]}">{VERDICTS[verdict][1]} {count} {verdict}</span>'
        for verdict, count in counts.items()
    )

    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>{STYLE}</style>
</head>
<body>
<main>
<h1>{title}</h1>
<dl class="meta">
<dt>Date</dt><dd>{html.escape(str(report["date"]))}</dd>
<dt>Before</dt><dd>{ref_text(report["before"])}</dd>
<dt>After</dt><dd>{ref_text(report["after"])}</dd>
</dl>
<div class="result">{chips}</div>
<section class="card">
<table>
<thead><tr><th>#</th><th>Test</th><th>Verdict</th></tr></thead>
<tbody>{"".join(rows)}</tbody>
</table>
</section>
{"".join(sections)}
{setup_html}
</main>
</body>
</html>
"""


def open_in_browser(path):
    """Open the page in the default browser; return a message saying how it went."""
    if sys.platform == "darwin":
        command = ["open", path]
    elif shutil.which("xdg-open") and (
        os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")
    ):
        command = ["xdg-open", path]
    else:
        return f"No display or opener here; open {path} in a browser yourself."
    process = subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    try:
        code = process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        return "Opened in the browser."
    if code != 0:
        return f"{command[0]} failed (exit {code}); open {path} in a browser yourself."
    return "Opened in the browser."


def main(argv):
    """Parse arguments, render the report, and open it."""
    args = [arg for arg in argv if arg != "--no-open"]
    if len(args) != 1 or args[0] in ("-h", "--help"):
        print(__doc__.split("JSON shape")[0].strip(), file=sys.stderr)
        return 2
    json_path = os.path.abspath(args[0])
    match = re.fullmatch(r"(\d+)-report\.json", os.path.basename(json_path))
    if not match:
        fail(
            [
                f"the file must be named <n>-report.json, not {os.path.basename(json_path)}"
            ]
        )
    base_dir = os.path.dirname(json_path)
    try:
        with open(json_path, encoding="utf-8") as handle:
            report = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        fail([str(error)])
    if not isinstance(report, dict):
        fail(["the top level must be an object"])
    errors = check(report, base_dir)
    if errors:
        fail(errors)
    report.setdefault(
        "date", datetime.date.fromtimestamp(os.path.getmtime(json_path)).isoformat()
    )

    html_path = os.path.join(base_dir, f"{match.group(1)}-report.html")
    with open(html_path, "w", encoding="utf-8") as handle:
        handle.write(render(report, match.group(1)))

    print(html_path)
    print(f"Result: {result_line(result_counts(report['tests']))}")
    if "--no-open" not in argv:
        print(open_in_browser(html_path))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
