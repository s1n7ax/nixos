#!/usr/bin/env python3
"""Post a /verify report, screenshots included, as a comment on a pull request.

Usage:
  publish.py [--pr <number|url|branch>] <dir>/<n>-report.json

Run it from the project's checkout. Without --pr it uses the open pull
request of the current branch. It checks the JSON the way report.py does,
uploads the screenshots to the PR's repository as one commit under the ref
refs/verify/pr-<number> (not a branch, so it never shows up in the branch
list, in clones or in the diff; each run replaces it), posts the report as a
comment, then deletes every earlier /verify comment on the PR, so the PR
only ever shows the latest run.

When the screenshot upload fails (a proxy that refuses git writes, a token
without contents access), it still posts the comment, without screenshots,
and writes <dir>/<n>-report-standalone.html: the report with every
screenshot embedded, to hand over instead. It prints that file's path.

Needs gh, logged in with write access to the repository. It uses only the
REST API, so it also works where GitHub's GraphQL API is blocked. Prints
the comment's URL. Exits 0 without posting when there is no open pull
request, and 1 on any other problem.
"""

import base64
import datetime
import html
import json
import os
import re
import subprocess
import sys
import urllib.parse

import report

MARKER = "<!-- verify-report -->"
LIMIT = 65536
TEXT_LIMITS = (None, 2000, 0)
IMAGE_WIDTH = 400


class GhError(Exception):
    """A gh command that failed, with its error."""


def die(message):
    """Print the problem and exit 1."""
    print(f"publish.py: {message}", file=sys.stderr)
    sys.exit(1)


def gh(args, payload=None):
    """Run gh and return its stdout; raise GhError when it fails."""
    try:
        result = subprocess.run(
            ["gh", *args],
            input=None if payload is None else json.dumps(payload),
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        die("needs gh (https://cli.github.com) on PATH, logged in")
    if result.returncode != 0:
        raise GhError(f"gh {' '.join(args[:4])} failed: {result.stderr.strip()}")
    return result.stdout


def api(pr, method, path, payload=None, jq=None):
    """Call the REST API of the PR's repository and return the parsed reply."""
    args = [
        "api",
        "--method",
        method,
        "--hostname",
        pr["host"],
        f"repos/{pr['owner']}/{pr['repo']}/{path}",
    ]
    if payload is not None:
        args += ["--input", "-"]
    if jq:
        args += ["--paginate", "--jq", jq]
    out = gh(args, payload)
    if jq:
        return out.split()
    return json.loads(out) if out.strip() else None


def git(*args):
    """Run git in the current directory; return its stdout, or '' on failure."""
    result = subprocess.run(["git", *args], capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def origin_repo():
    """(host, owner, repo) of the checkout's origin remote.

    The repository is the URL's last two path segments, so a git proxy's
    prefix (http://proxy@127.0.0.1:<port>/git/<owner>/<repo>) reads too. A
    remote on a loopback or IP address is such a proxy, standing in for
    github.com.
    """
    url = git("remote", "get-url", "origin")
    match = re.fullmatch(
        r"(?:[a-z+]+://)?(?:[^@/]+@)?([^/:]+)(?::\d+)?[/:](?:.*/)?"
        r"([^/]+)/([^/]+?)(?:\.git)?/?",
        url,
    )
    if not match:
        die(
            f"cannot read the repository from the origin remote {url!r}; pass --pr <url>"
        )
    host, owner, repo = match.groups()
    if host == "localhost" or re.fullmatch(r"[\d.]+|\[[\da-f:]*\]", host):
        host = "github.com"
    return host, owner, repo


def upstream_branch():
    """The current branch's name on origin: its upstream there, else its own."""
    upstream = git("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}")
    if upstream.startswith("origin/"):
        return upstream.removeprefix("origin/")
    return git("branch", "--show-current")


def find_pr(selector):
    """The open PR to post on, or None when there is none.

    Read over REST rather than `gh pr view`, which needs the GraphQL API.
    A number or branch is looked up in the origin remote's repository; a PR
    on another repository (a fork's upstream) needs its URL.
    """
    selector = (selector or "").strip()
    match = re.fullmatch(
        r"(?:https?://)?([^/]+)/([^/]+)/([^/]+)/pull/(\d+)(?:[/?#].*)?", selector
    )
    if match:
        host, owner, repo, number = match.groups()
        branch = None
    else:
        host, owner, repo = origin_repo()
        digits = re.fullmatch(r"#?(\d+)", selector)
        number = digits.group(1) if digits else None
        branch = None if number else selector or upstream_branch()
        if not number and not branch:
            die("not on a branch; pass --pr <number|url|branch>")
    pr = {"host": host, "owner": owner, "repo": repo}
    if number:
        found = api(pr, "GET", f"pulls/{number}")
    else:
        query = urllib.parse.urlencode(
            {"head": f"{owner}:{branch}", "state": "open", "per_page": 1}
        )
        found = next(iter(api(pr, "GET", f"pulls?{query}")), None)
    if not found or found["state"] != "open":
        return None
    pr.update(
        number=found["number"],
        url=found["html_url"],
        headRefName=found["head"]["ref"],
        headRefOid=found["head"]["sha"],
    )
    return pr


def screenshots(data, base_dir):
    """Every screenshot path in the report, once each, in report order."""
    paths = []
    for test in data["tests"]:
        for side in ("before", "after"):
            info = test.get(side) or {}
            for image in report.as_list(info.get("images")):
                path = os.path.normpath(image)
                if path.startswith("..") or os.path.isabs(path):
                    die(f"screenshot {image} is outside {base_dir}")
                if path not in paths:
                    paths.append(path)
    return paths


def upload(pr, paths, base_dir, number):
    """Commit the screenshots under refs/verify/pr-<n>; return the commit SHA.

    With no screenshots, delete the ref so no earlier run's are left, and
    return None.
    """
    ref = f"verify/pr-{pr['number']}"
    existing = api(pr, "GET", f"git/matching-refs/{ref}")
    exists = any(entry["ref"] == f"refs/{ref}" for entry in existing)
    if not paths:
        if exists:
            api(pr, "DELETE", f"git/refs/{ref}")
        return None
    tree = []
    for path in paths:
        with open(os.path.join(base_dir, path), "rb") as handle:
            content = base64.b64encode(handle.read()).decode()
        blob = api(pr, "POST", "git/blobs", {"content": content, "encoding": "base64"})
        tree.append(
            {"path": path, "mode": "100644", "type": "blob", "sha": blob["sha"]}
        )
    tree_sha = api(pr, "POST", "git/trees", {"tree": tree})["sha"]
    commit = api(
        pr,
        "POST",
        "git/commits",
        {
            "message": f"/verify report {number} for #{pr['number']}",
            "tree": tree_sha,
            "parents": [],
        },
    )["sha"]
    if exists:
        api(pr, "PATCH", f"git/refs/{ref}", {"sha": commit, "force": True})
    else:
        api(pr, "POST", "git/refs", {"ref": f"refs/{ref}", "sha": commit})
    return commit


def text(value):
    """Escape for HTML and render `backticks` as code, keeping the line breaks."""
    return report.inline(value).replace("\n", "<br>")


def badge(verdict):
    """The verdict with its icon."""
    return f"{report.VERDICTS[verdict][1]} <strong>{verdict}</strong>"


def side_cell(name, info, image_url):
    """One cell of the before/after table; image_url None means none uploaded."""
    if info is None:
        return "<em>n/a: did not exist before the change.</em>"
    images = report.as_list(info.get("images"))
    if not images:
        parts = ["<em>No screenshot.</em>"]
    elif image_url is None:
        count = "1 screenshot" if len(images) == 1 else f"{len(images)} screenshots"
        parts = [f"<em>{count}, not uploaded: see the standalone report.</em>"]
    else:
        parts = [
            f'<img src="{html.escape(image_url(image), quote=True)}" '
            f'width="{IMAGE_WIDTH}" alt="{name} screenshot">'
            for image in images
        ]
    if info.get("note"):
        parts.append(text(info["note"]))
    return "<br>".join(parts)


def text_dump(name, info, limit):
    """A collapsed screen-text dump for one side, or '' when there is none."""
    dump = (info or {}).get("text")
    if not dump or limit == 0:
        return ""
    if limit is not None and len(dump) > limit:
        dump = dump[:limit] + "\n… (truncated)"
    return (
        f"<details><summary>{name}: screen text</summary>\n\n"
        f"<pre>\n{html.escape(dump)}\n</pre>\n\n</details>\n"
    )


def render(data, number, pr, image_url, limit, not_uploaded=None):
    """The whole comment, in the HTML subset GitHub renders.

    not_uploaded, when the screenshots could not be uploaded, is the
    standalone report's file name, named in a notice at the top.
    """
    tests = data["tests"]
    counts = report.result_counts(tests)
    result = " · ".join(
        f"{report.VERDICTS[verdict][1]} {count} {verdict}"
        for verdict, count in counts.items()
    )
    lines = [
        MARKER,
        f"<h2>Verification {number} — {html.escape(data['goal'])}</h2>",
        f"<p><strong>Result:</strong> {result}</p>",
        "<p>"
        f"<strong>Date:</strong> {html.escape(str(data['date']))}<br>"
        f"<strong>Before:</strong> {report.ref_text(data['before'])}<br>"
        f"<strong>After:</strong> {report.ref_text(data['after'])}"
        "</p>",
    ]
    if not_uploaded:
        lines.append(
            "<p>⚠️ The screenshots could not be uploaded to this repository, so "
            "this comment has none. They are in the standalone report "
            f"<code>{html.escape(not_uploaded)}</code>, which embeds every "
            "screenshot, on the machine that ran <code>/verify</code>.</p>"
        )
    sha = data["after"].get("sha")
    if sha and not pr["headRefOid"].startswith(sha):
        lines.append(
            f"<p>⚠️ Verified at {html.escape(sha)}; the PR head was "
            f"{pr['headRefOid'][:7]} when this was posted.</p>"
        )
    rows = "".join(
        f"<tr><td>{index}</td><td>{text(test['title'])}</td>"
        f"<td>{badge(report.normalise(test['verdict']))}</td></tr>"
        for index, test in enumerate(tests, 1)
    )
    lines.append(
        f"<table><tr><th>#</th><th>Test</th><th>Verdict</th></tr>{rows}</table>"
    )

    for index, test in enumerate(tests, 1):
        verdict = report.normalise(test["verdict"])
        lines.append(f"<h3>{index}. {text(test['title'])} — {badge(verdict)}</h3>")
        if test.get("why"):
            label = "What happened" if verdict == "FAIL" else "Why"
            lines.append(
                f"<blockquote><strong>{label}:</strong> {text(test['why'])}</blockquote>"
            )
        steps = "".join(
            f"<li>{text(step)}</li>" for step in report.as_list(test.get("steps"))
        )
        lines.append(f"<p><strong>Steps</strong></p><ol>{steps}</ol>")
        before, after = test.get("before"), test.get("after")
        lines.append(
            "<table><tr><th>Before</th><th>After</th></tr><tr>"
            f'<td valign="top">{side_cell("Before", before, image_url)}</td>'
            f'<td valign="top">{side_cell("After", after, image_url)}</td>'
            "</tr></table>"
        )
        lines.append(text_dump("Before", before, limit))
        lines.append(text_dump("After", after, limit))

    setup = [
        f"<li><strong>{side.capitalize()}:</strong> {text(data[side]['setup'])}</li>"
        for side in ("before", "after")
        if data[side].get("setup")
    ]
    setup += [f"<li>{text(note)}</li>" for note in report.as_list(data.get("notes"))]
    if setup:
        lines.append(f"<h3>Setup</h3><ul>{''.join(setup)}</ul>")
    lines.append(
        "<p><sub>Posted by <code>/verify</code>. "
        "Running it again replaces this comment.</sub></p>"
    )
    return "\n\n".join(line for line in lines if line)


def main(argv):
    """Check the report, upload its screenshots, and replace the PR's verify comment."""
    args = list(argv)
    selector = None
    if "--pr" in args:
        index = args.index("--pr")
        if index + 1 >= len(args):
            print(__doc__.split("Run it")[0].strip(), file=sys.stderr)
            return 2
        selector = args[index + 1]
        del args[index : index + 2]
    if len(args) != 1 or args[0] in ("-h", "--help"):
        print(__doc__.split("Run it")[0].strip(), file=sys.stderr)
        return 2
    json_path = os.path.abspath(args[0])
    match = re.fullmatch(r"(\d+)-report\.json", os.path.basename(json_path))
    if not match:
        die(
            f"the file must be named <n>-report.json, not {os.path.basename(json_path)}"
        )
    number = match.group(1)
    base_dir = os.path.dirname(json_path)
    try:
        with open(json_path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        die(str(error))
    if not isinstance(data, dict):
        report.fail(["the top level must be an object"])
    errors = report.check(data, base_dir)
    if errors:
        report.fail(errors)
    data.setdefault(
        "date", datetime.date.fromtimestamp(os.path.getmtime(json_path)).isoformat()
    )

    pr = find_pr(selector)
    if pr is None:
        where = selector or "the current branch"
        print(f"No open pull request for {where}; nothing posted.")
        return 0

    paths = screenshots(data, base_dir)
    standalone = None
    # A standalone report from an earlier failed upload is stale once this
    # run's screenshots go up, so it never outlives the run that needed it.
    stale = report.standalone_path(base_dir, number)
    if os.path.exists(stale):
        os.remove(stale)
    try:
        commit = upload(pr, paths, base_dir, number)
    except GhError as error:
        # Post the report anyway; the screenshots go in a file to hand over.
        print(f"Screenshots not uploaded: {error}")
        commit = None
        if paths:
            standalone = report.write_standalone(data, number, base_dir)

    def image_url(image):
        """The URL GitHub serves an uploaded screenshot at."""
        path = urllib.parse.quote(os.path.normpath(image))
        return f"https://{pr['host']}/{pr['owner']}/{pr['repo']}/raw/{commit}/{path}"

    url_of = None if standalone else image_url
    not_uploaded = os.path.basename(standalone) if standalone else None
    for limit in TEXT_LIMITS:
        body = render(data, number, pr, url_of, limit, not_uploaded)
        if len(body) <= LIMIT:
            break
    else:
        die(f"the comment is {len(body)} characters; GitHub allows {LIMIT}")

    old = api(
        pr,
        "GET",
        f"issues/{pr['number']}/comments",
        jq=f".[] | select(.body | startswith({json.dumps(MARKER)})) | .id",
    )
    posted = api(pr, "POST", f"issues/{pr['number']}/comments", {"body": body})
    print(posted["html_url"])
    print(f"Result: {report.result_line(report.result_counts(data['tests']))}")
    for comment in old:
        api(pr, "DELETE", f"issues/comments/{comment}")
    print(f"Removed {len(old)} earlier /verify comment(s).")
    if standalone:
        print(f"Standalone report, screenshots embedded: {standalone}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except GhError as error:
        die(str(error))
