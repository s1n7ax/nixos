#!/usr/bin/env python3
"""List the tasks /ship can pick up, and claim one so no two agents take it.

Usage:
  tasks.py list
  tasks.py claim [--force] <task>
  tasks.py release [--force] <task>

A task is goal:<name>, a goal directory under .goals/, or issue:<n>, an open
GitHub issue labelled agent:ship. Run it anywhere in the repository or in
one of its worktrees: goals and claims always live in the main checkout's
.goals/, so every worktree sees the same ones. A goal whose directory holds
an `issue` file (the issue's number) is that issue's work, and goes by
issue:<n>.

list prints the tasks not finished yet, numbered: a goal with no open or
merged PR from its branch (or from one of its <goal>_approach_* branches),
an issue with no open or merged PR that closes it. Then it prints the tasks
another live agent holds.

A claim belongs to the agent process that ran the script: its first
ancestor that is not a shell or a wrapper. It goes stale when that process
exits, and a stale claim holds nothing. claim takes a task atomically: of
two agents claiming one task at once, one wins and the other exits 2 naming
the holder. An issue also gets the agent:shipping label, so agents on other
machines skip it. --force takes a task another live agent holds. release
gives it back.

Needs git, and gh logged in for issues and PRs; without gh, list shows the
goals alone and says why. Exits 1 on any other problem.
"""

import contextlib
import datetime
import fcntl
import json
import os
import re
import socket
import subprocess
import sys

SHIP_LABEL = "agent:ship"
CLAIM_LABEL = "agent:shipping"
WRAPPERS = {
    "bash",
    "bwrap",
    "dash",
    "env",
    "fish",
    "nice",
    "nix",
    "sandbox-exec",
    "script",
    "sh",
    "stdbuf",
    "sudo",
    "timeout",
    "uv",
    "xargs",
    "zsh",
}


def die(message, code=1):
    """Print the problem and exit with code."""
    print(f"tasks.py: {message}", file=sys.stderr)
    sys.exit(code)


def run(args):
    """Run a command; return its exit code, stdout and stderr."""
    try:
        result = subprocess.run(args, capture_output=True, text=True)
    except FileNotFoundError:
        return 127, "", f"{args[0]} is not on PATH"
    return result.returncode, result.stdout, result.stderr.strip()


def git(*args):
    """Run git and return its stdout; exit with its error when it fails."""
    code, out, err = run(["git", *args])
    if code:
        die(f"git {' '.join(args)} failed: {err}")
    return out.strip()


def gh_json(*args):
    """Run gh and return its parsed stdout and None, or None and the error."""
    code, out, err = run(["gh", *args])
    if code:
        return None, err or f"gh exited {code}"
    return json.loads(out), None


def parse(task):
    """Split goal:<name> or issue:<n> into its kind and key."""
    match = re.fullmatch(r"(goal):([a-z0-9][a-z0-9._-]*)|(issue):#?([0-9]+)", task)
    if not match:
        die(f"{task!r} is not goal:<name> or issue:<n>")
    if match[1]:
        return match[1], match[2]
    return match[3], match[4]


def goals_dir():
    """The main checkout's .goals/, shared by all of its worktrees."""
    first = git("worktree", "list", "--porcelain").splitlines()[0]
    return os.path.join(first.removeprefix("worktree "), ".goals")


def canonical(goals, kind, key):
    """The task's own name: a goal working an issue goes by the issue."""
    if kind == "goal":
        marker = os.path.join(goals, key, "issue")
        if os.path.isfile(marker):
            with open(marker) as file:
                number = file.read().strip().lstrip("#")
            if number.isdigit():
                return "issue", number
    return kind, key


def process(pid):
    """A running process's parent, start time and name, or None when gone."""
    code, out, _ = run(
        ["ps", "-o", "ppid=", "-o", "lstart=", "-o", "comm=", "-p", str(pid)]
    )
    parts = out.split()
    if code or len(parts) < 7:
        return None
    return {
        "ppid": int(parts[0]),
        "started": " ".join(parts[1:6]),
        "name": os.path.basename(" ".join(parts[6:])),
    }


def agent():
    """This agent's process: the first ancestor that is not a shell or wrapper."""
    pid = os.getppid()
    while True:
        info = process(pid)
        if info is None:
            die(f"cannot read process {pid}")
        name = info["name"].lstrip(".").removesuffix("-wrapped")
        wrapper = name in WRAPPERS or name.startswith("python")
        if not wrapper or info["ppid"] <= 1:
            return {
                "host": socket.gethostname(),
                "pid": pid,
                "started": info["started"],
                "name": name,
            }
        pid = info["ppid"]


def same(a, b):
    """Whether two owners are the same process."""
    return all(a[key] == b[key] for key in ("host", "pid", "started"))


def alive(owner):
    """Whether the owner still runs; another machine's owner is assumed to."""
    if owner["host"] != socket.gethostname():
        return True
    info = process(owner["pid"])
    return info is not None and info["started"] == owner["started"]


def describe(claim):
    """Who holds a claim, for people."""
    owner = claim["owner"]
    return (
        f"{owner['name']} pid {owner['pid']} on {owner['host']}"
        f" since {claim['claimed_at'].replace('T', ' ')[:16]}"
    )


def claim_path(goals, kind, key):
    return os.path.join(goals, ".claims", f"{kind}--{key}.json")


def read_claim(path):
    """The claim stored at path, or None."""
    try:
        with open(path) as file:
            return json.load(file)
    except FileNotFoundError:
        return None


@contextlib.contextmanager
def locked(goals):
    """Hold the claims lock, so check-then-claim is one step for every agent."""
    if not os.path.exists(os.path.join(goals, ".gitignore")):
        os.makedirs(goals, exist_ok=True)
        with open(os.path.join(goals, ".gitignore"), "w") as file:
            file.write("*\n")
    os.makedirs(os.path.join(goals, ".claims"), exist_ok=True)
    with open(os.path.join(goals, ".claims", ".lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def gh_or_die(*args):
    code, _, err = run(["gh", *args])
    if code:
        die(f"gh {' '.join(args[:3])} failed: {err}")


def claim(task, force):
    goals = goals_dir()
    kind, key = canonical(goals, *parse(task))
    task = f"{kind}:{key}"
    me = agent()
    path = claim_path(goals, kind, key)
    with locked(goals):
        held = read_claim(path)
        if held and same(held["owner"], me):
            print(f"{task} is already yours")
            return
        if held and alive(held["owner"]) and not force:
            die(f"{task} is taken by {describe(held)}", 2)
        if kind == "issue":
            issue, err = gh_json("issue", "view", key, "--json", "state,labels")
            if err:
                die(f"cannot read issue {key}: {err}")
            if issue["state"] != "OPEN":
                die(f"issue {key} is closed")
            labelled = CLAIM_LABEL in {label["name"] for label in issue["labels"]}
            if labelled and not held and not force:
                die(
                    f"{task} has the {CLAIM_LABEL} label: an agent on another machine holds it",
                    2,
                )
            gh_or_die(
                "label",
                "create",
                CLAIM_LABEL,
                "--force",
                "--color",
                "FBCA04",
                "--description",
                "A /ship agent is working on this",
            )
            gh_or_die("issue", "edit", key, "--add-label", CLAIM_LABEL)
        record = {
            "task": task,
            "owner": me,
            "claimed_at": datetime.datetime.now()
            .astimezone()
            .isoformat(timespec="seconds"),
        }
        with open(path + ".tmp", "w") as file:
            json.dump(record, file, indent=2)
        os.replace(path + ".tmp", path)
    note = f", taking it from {describe(held)}" if held else ""
    print(f"claimed {task}{note}")


def release(task, force):
    goals = goals_dir()
    kind, key = canonical(goals, *parse(task))
    task = f"{kind}:{key}"
    me = agent()
    path = claim_path(goals, kind, key)
    with locked(goals):
        held = read_claim(path)
        if not held and not force:
            print(f"{task} was not claimed")
            return
        if held and not same(held["owner"], me) and alive(held["owner"]) and not force:
            die(f"{task} is held by {describe(held)}, not by this agent", 2)
        if held:
            os.remove(path)
        if kind == "issue":
            gh_or_die("issue", "edit", key, "--remove-label", CLAIM_LABEL)
    print(f"released {task}")


def base_branch():
    """The ref new goal branches start from, or None."""
    for args in (
        ["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"],
        ["rev-parse", "--verify", "--quiet", "--abbrev-ref", "main"],
        ["rev-parse", "--verify", "--quiet", "--abbrev-ref", "master"],
    ):
        code, out, _ = run(["git", *args])
        if code == 0 and out.strip():
            return out.strip()
    return None


def goal_entry(goals, name, base):
    """A goal's title and how far it got."""
    directory = os.path.join(goals, name)
    title = name
    progress = []
    requirement = os.path.join(directory, "requirement", "requirement.md")
    if os.path.isfile(requirement):
        progress.append("requirement")
        with open(requirement) as file:
            for line in file:
                if line.startswith("# "):
                    title = line[2:].strip()
                    break
    else:
        progress.append("no requirement yet")
    if os.path.isfile(os.path.join(directory, "decisions", "decisions.md")):
        progress.append("decisions")
    if base:
        code, out, _ = run(["git", "rev-list", "--count", f"{base}..refs/heads/{name}"])
        if code == 0 and out.strip() != "0":
            progress.append(f"{out.strip()} commits")
    return title, ", ".join(progress)


def list_tasks():
    goals = goals_dir()
    held = {}
    if os.path.isdir(os.path.join(goals, ".claims")):
        for entry in os.listdir(os.path.join(goals, ".claims")):
            if entry.endswith(".json"):
                record = read_claim(os.path.join(goals, ".claims", entry))
                if record:
                    held[record["task"]] = record
    me = agent()
    available, taken, missing = [], [], []

    def add(task, title, progress, labelled=False):
        record = held.get(task)
        if record and not same(record["owner"], me) and alive(record["owner"]):
            taken.append((task, title, describe(record)))
        elif labelled and not record:
            taken.append((task, title, f"{CLAIM_LABEL} label, held on another machine"))
        else:
            if record and same(record["owner"], me):
                progress += ", yours"
            elif record:
                progress += ", its last agent exited"
            available.append((task, title, progress))

    prs, err = gh_json(
        "pr",
        "list",
        "--state",
        "all",
        "--limit",
        "1000",
        "--json",
        "number,headRefName,state",
    )
    if err:
        missing.append(
            f"PR state (gh pr list failed: {err}), so shipped goals may show up"
        )
        prs = []
    live = [pr for pr in prs if pr["state"] in ("OPEN", "MERGED")]
    known = {pr["number"]: pr["state"] for pr in prs}

    base = base_branch()
    names = sorted(os.listdir(goals)) if os.path.isdir(goals) else []
    for name in names:
        if name.startswith(".") or not os.path.isdir(os.path.join(goals, name)):
            continue
        if canonical(goals, "goal", name)[0] == "issue":
            continue
        heads = (pr["headRefName"] for pr in live)
        if any(head == name or head.startswith(f"{name}_approach_") for head in heads):
            continue
        add(f"goal:{name}", *goal_entry(goals, name, base))

    issues, err = gh_json(
        "issue",
        "list",
        "--label",
        SHIP_LABEL,
        "--state",
        "open",
        "--limit",
        "200",
        "--json",
        "number,title,body,labels,closedByPullRequestsReferences",
    )
    if err:
        missing.append(f"issues (gh issue list failed: {err})")
        issues = []
    for issue in sorted(issues, key=lambda issue: issue["number"]):
        linked = issue["closedByPullRequestsReferences"]
        # A PR this listing has not seen (another repository, or older than
        # the PR list reaches) counts as live: better hidden than done twice.
        if any(known.get(pr["number"], "OPEN") in ("OPEN", "MERGED") for pr in linked):
            continue
        written = re.search(r"^## Acceptance criteria", issue["body"] or "", re.M)
        progress = "requirement" if written else "no requirement yet"
        labelled = CLAIM_LABEL in {label["name"] for label in issue["labels"]}
        add(f"issue:{issue['number']}", issue["title"], progress, labelled)

    if available:
        print("Tasks:")
        for n, (task, title, progress) in enumerate(available, 1):
            print(f"  {n}. {task} — {title} ({progress})")
    else:
        print("No tasks.")
    if taken:
        print("\nTaken by other agents:")
        for task, title, holder in taken:
            print(f"  - {task} — {title} ({holder})")
    for what in missing:
        print(f"\nNot listed: {what}")


def main(argv):
    force = "--force" in argv
    args = [arg for arg in argv if arg != "--force"]
    if args == ["list"] and not force:
        list_tasks()
    elif len(args) == 2 and args[0] == "claim":
        claim(args[1], force)
    elif len(args) == 2 and args[0] == "release":
        release(args[1], force)
    else:
        die("usage: tasks.py list | claim [--force] <task> | release [--force] <task>")


if __name__ == "__main__":
    main(sys.argv[1:])
