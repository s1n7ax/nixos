#!/usr/bin/env python3
"""Wait for a PR's CI without spending tokens, and say whether it can merge.

Usage:
  pr.py wait [--final] [--timeout <seconds>] [<pr>]
  pr.py status [<pr>]

<pr> is a number, URL or branch; it defaults to the current branch's PR.

wait polls GitHub until every check on the PR's head commit has finished,
then exits with a verdict. Run it in the background (Claude Code: Bash with
run_in_background) so nothing is spent while CI runs: the harness wakes the
agent when it exits. Without background tasks, run it in the foreground with
--timeout below the tool's limit, and run it again on exit 124.

status prints the verdict once, without waiting, and exits 124 while checks
are pending.

Both write the PR's state to <git dir>/ship-ci.json (the worktree's own git
dir) on every poll, which the Claude Code status line shows. Reading that
file is the only way progress should be watched.

Exit codes:
  0  green: every check passed, and the PR merges cleanly. A PR that only
     waits for a human review is green: that approval is the user's.
  1  red: a check failed. The failed checks are printed, each GitHub
     Actions job with the part of its failed log that leads to the error.
  2  not ready for CI: local HEAD is not the PR's head commit (push first),
     or the PR is closed or merged.
  3  conflict: the branch conflicts with the base, or is behind a base that
     requires it to be up to date. Merge the base in, push,
     and wait again.
  4  draft (--final only): the PR is still a draft; run `gh pr ready`.
  124 checks are still pending: the --timeout ran out, or status found them
      running.
  Exits 5 on any other problem (no gh, no PR, bad arguments).

A PR with no checks at all is green once GRACE seconds pass after its head
commit, and GRACE seconds of waiting, without any check appearing, for
repositories without CI.
"""

import json
import os
import re
import subprocess
import sys
import time

POLL = 20
GRACE = 120
LOG_LINES = 60
FIELDS = (
    "number,url,state,isDraft,headRefName,headRefOid,baseRefName,"
    "mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,commits"
)
PASSING = {"SUCCESS", "NEUTRAL", "SKIPPED"}
PENDING = {"PENDING", "EXPECTED", "QUEUED", "IN_PROGRESS", "WAITING", "REQUESTED"}


def die(message, code=5):
    """Print the problem and exit with code."""
    print(f"pr.py: {message}", file=sys.stderr)
    sys.exit(code)


def run(args):
    """Run a command; return its exit code, stdout and stderr."""
    try:
        result = subprocess.run(args, capture_output=True, text=True)
    except FileNotFoundError:
        return 127, "", f"{args[0]} is not on PATH"
    return result.returncode, result.stdout, result.stderr.strip()


def git(*args):
    """Run git; return its stdout stripped, or None when it fails."""
    code, out, _ = run(["git", *args])
    return out.strip() if code == 0 else None


def fetch(pr):
    """Return the PR's fields from gh, or exit when gh cannot read them."""
    code, out, err = run(["gh", "pr", "view", *([pr] if pr else []), "--json", FIELDS])
    if code != 0:
        die(err or "gh pr view failed")
    return json.loads(out)


def checks(data):
    """Return the head commit's checks as (name, state, url) tuples."""
    result = []
    for item in data.get("statusCheckRollup") or []:
        if item.get("__typename") == "StatusContext":
            name, state, url = (
                item.get("context"),
                item.get("state"),
                item.get("targetUrl"),
            )
        else:
            name, url = item.get("name"), item.get("detailsUrl")
            state = (
                item.get("conclusion")
                if item.get("status") == "COMPLETED"
                else item.get("status")
            )
            if item.get("workflowName") and item["workflowName"] != name:
                name = f"{item['workflowName']} / {name}"
        result.append((name or "?", (state or "PENDING").upper(), url or ""))
    return result


def head_age(data):
    """Return seconds since the head commit was committed, or None."""
    commits = data.get("commits") or []
    stamp = commits[-1].get("committedDate") if commits else None
    if not stamp:
        return None
    code, out, _ = run(["date", "-d", stamp, "+%s"])
    return time.time() - int(out) if code == 0 else None


def verdict(data, final, waited):
    """Classify the PR; return (status, exit code or None while pending, lines)."""
    if data["state"] != "OPEN":
        return data["state"].lower(), 2, [f"PR is {data['state'].lower()}."]
    local = git("rev-parse", "HEAD")
    if (
        local
        and git("rev-parse", "--abbrev-ref", "HEAD") == data["headRefName"]
        and local != data["headRefOid"]
    ):
        return (
            "unpushed",
            2,
            [
                f"Local HEAD {local[:9]} is not the PR head {data['headRefOid'][:9]}: push first."
            ],
        )

    all_checks = checks(data)
    failed = [c for c in all_checks if c[1] not in PASSING | PENDING]
    pending = [c for c in all_checks if c[1] in PENDING]
    if failed:
        return (
            "red",
            1,
            [f"Failed: {name} ({state.lower()}) {url}" for name, state, url in failed],
        )
    if data["mergeable"] == "CONFLICTING" or data["mergeStateStatus"] == "DIRTY":
        return (
            "conflict",
            3,
            [
                f"Conflicts with {data['baseRefName']}: merge it in, resolve, push, and wait again."
            ],
        )
    if data["mergeStateStatus"] == "BEHIND":
        return (
            "conflict",
            3,
            [
                f"Behind {data['baseRefName']}, which must be up to date: merge it in, push, and wait again."
            ],
        )
    if pending:
        return "pending", None, []
    if not all_checks:
        age = head_age(data)
        if waited < GRACE or age is None or age < GRACE:
            return "pending", None, []
    if data["mergeable"] == "UNKNOWN":
        return "pending", None, []
    if final and data["isDraft"]:
        return (
            "draft",
            4,
            [
                "Every check passed, but the PR is a draft: run `gh pr ready`, then wait again."
            ],
        )

    lines = [
        f"Every check passed ({len(all_checks)})."
        if all_checks
        else "No checks ran on this PR."
    ]
    if data["isDraft"]:
        lines.append("PR is a draft.")
    if data["reviewDecision"] in {"REVIEW_REQUIRED", "CHANGES_REQUESTED"}:
        lines.append(f"Waiting for a human review ({data['reviewDecision'].lower()}).")
    elif data["mergeStateStatus"] == "BLOCKED" and not data["isDraft"]:
        lines.append(
            "GitHub still reports the merge as blocked by a rule other than checks; tell the user."
        )
    return "green", 0, lines


def write_state(data, status, started, watching):
    """Write the PR's state to <git dir>/ship-ci.json for the status line."""
    gitdir = git("rev-parse", "--absolute-git-dir")
    if not gitdir:
        return
    all_checks = checks(data)
    state = {
        "pr": data["number"],
        "url": data["url"],
        "sha": data["headRefOid"],
        "status": status,
        "total": len(all_checks),
        "passed": sum(c[1] in PASSING for c in all_checks),
        "pending": sum(c[1] in PENDING for c in all_checks),
        "failed": [c[0] for c in all_checks if c[1] not in PASSING | PENDING],
        "watcher": os.getpid() if watching and status == "pending" else None,
        "started": started,
        "updated": int(time.time()),
    }
    path = os.path.join(gitdir, "ship-ci.json")
    with open(path + ".tmp", "w") as f:
        json.dump(state, f)
    os.replace(path + ".tmp", path)


def failed_logs(data):
    """Print the tail of each failed GitHub Actions job's log."""
    for name, state, url in checks(data):
        if state in PASSING | PENDING:
            continue
        match = re.search(r"/actions/runs/(\d+)/job/(\d+)", url)
        if not match:
            continue
        command = ["gh", "run", "view", match[1], "--job", match[2], "--log-failed"]
        code, out, err = run(command)
        lines = [
            re.sub(r"^[^\t]*\t[^\t]*\t\S+Z ", "", line)
            for line in (out if code == 0 else err).splitlines()
        ]
        marker = next(
            (i for i, line in enumerate(lines) if line.startswith("##[error]")), None
        )
        if marker is None:
            excerpt, where = lines[-LOG_LINES:], "last lines"
        else:
            excerpt, where = (
                lines[max(0, marker - LOG_LINES + 5) : marker + 5],
                "lines up to the first error",
            )
        print(
            f"\n--- {name}: {where} of the failed log (full log: {' '.join(command)}) ---"
        )
        print("\n".join(excerpt))


def main():
    args = sys.argv[1:]
    if not args or args[0] not in {"wait", "status"}:
        die(__doc__.split("\n\n")[1])
    command, args = args[0], args[1:]
    final = "--final" in args
    args = [a for a in args if a != "--final"]
    timeout = None
    if "--timeout" in args:
        i = args.index("--timeout")
        try:
            timeout = int(args[i + 1])
        except (IndexError, ValueError):
            die("--timeout takes a number of seconds")
        del args[i : i + 2]
    if len(args) > 1:
        die("takes at most one PR")
    pr = args[0] if args else None

    started = int(time.time())
    while True:
        data = fetch(pr)
        status, code, lines = verdict(data, final, time.time() - started)
        write_state(data, status, started, command == "wait")
        if code is not None or command == "status":
            print(f"PR #{data['number']} {data['url']}: {status}")
            for line in lines:
                print(line)
            if status == "pending":
                done = sum(c[1] not in PENDING for c in checks(data))
                print(f"{done}/{len(checks(data))} checks finished.")
            if code == 1:
                failed_logs(data)
            sys.exit(124 if code is None else code)
        if timeout is not None and time.time() - started >= timeout:
            print(
                f"PR #{data['number']}: checks still pending after {timeout}s; run wait again."
            )
            sys.exit(124)
        time.sleep(POLL)


if __name__ == "__main__":
    main()
