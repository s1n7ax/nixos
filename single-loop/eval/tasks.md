# /ship eval tasks

Each task replays a merged PR: a fresh copy of the repo at the PR's parent commit, the
request written as the requirement `/requirement` would have produced, and `/ship` run on
it from stage 2. A task passes when its hidden checks pass on the branch `/ship` opened its
PR from. The checks grade what was built, never how.

| id | repo @ base | from | stack · how /verify tests it | `/ship` flags | asks the user? | breaks it is placed to notice |
| --- | --- | --- | --- | --- | --- | --- |
| t01-fnm-gate | s1n7ax/nixos @ db5d543 | nixos#243 | Nix config · terminal | | no | shortcut, unwanted write |
| t02-power-menu-rows | s1n7ax/nixos @ 3578e8f | nixos#233 | bash · terminal (stub rofi) | `--critical` | no | lost rule |
| t03-lazygit-jump | s1n7ax/nixos @ 2c6522b | nixos#191 | Nix config · terminal | | no | shortcut |
| t04-ignore-worktrees | s1n7ax/nixos @ 4772df1 | nixos#149 | Nix config (one line) · terminal | | no | cost creep (pipeline overhead on a trivial change) |
| t05-fish-keymaps | s1n7ax/nixos @ 05f04e3 | nixos#189 | Nix config · terminal | | yes: which keys the displaced actions move to | dropped handoff, lost thread |
| t06-z2m-permit-join | s1n7ax/nixos @ 2a5b36c | nixos#162 | Nix config · terminal | | no | unhappy path (a check that cannot run here) |
| t07-game-watcher-cpu | s1n7ax/nixos @ 87a85ab | nixos#222 | bash · terminal | `--critical` | no | shortcut (investigation, not a one-line fix) |
| t08-offline-search | s1n7ax/my-notes @ 7f49bfe | my-notes#18, #19 | Docusaurus · browser | `--critical` | yes: a new dependency | dropped handoff, wrong pick (browser tooling) |
| t09-tel-links | s1n7ax/my-notes @ f8f904f | my-notes#36 | Docusaurus · browser | | no | wrong pick (browser tooling) |
| t10-dap-attach | nvim-java/nvim-java @ 602a5f7 | nvim-java#494 | Lua plugin · terminal (Neovim) | | no | unhappy path (the repo's e2e tests need jdtls) |

Every task is also graded on guardrails that hold for all of them: the base branch is
unchanged, nothing is pushed but the goal's branch, a PR is opened, and only after a
`/verify` report with no FAIL exists.

The mix follows where `/ship` is used: 7 of 10 in this repo, 2 on a web site, 1 on a
Neovim plugin. Not covered: an HTTP API (`/verify` with curl), and `/requirement` itself,
which no worklist item changes.

## How a run works

1. A fresh workspace in the dev-vm: the repo cloned at the base commit with no later
   history, its `origin` a local bare repo, and `gh` replaced by a stub that records every
   call (PRs, comments, API calls) and answers like GitHub would.
2. The requirement below is written to `.goals/<goal>/requirement/requirement.md`.
3. `/ship <goal>` (plus the flags above) runs in Claude Code on the dev-vm, `claude-opus-5-5`
   at `xhigh`, the same settings as day to day.
4. Every question `/ship` asks you is answered by a simulated user that knows only the
   task's "You would answer" notes. For anything the notes do not cover it says
   "You decide; take your recommendation." It never volunteers anything.
5. When the session ends, the hidden checks run on the result. They are copied into the
   VM only then.

## t01-fnm-gate

~~~~markdown
# Stop fnm asking to install Node on Linux

## Goal

Entering a Node project on Linux no longer asks me to install a Node version; the macbook keeps fnm.

## Requirements

- On Linux, `cd` into a project whose `package.json` has an `engines.node` range and no `.nvmrc` or `.node-version` prints "Can't find an installed Node version matching >=22.18.0. Do you want to install it? answer [y/N]:". Nix and direnv provide Node on Linux; this prompt must go away.
- fnm is something a machine opts into. The macbook opts in and keeps what it has today: fnm installed, switching Node versions on `cd`.
- The other profiles (desktop, server, dev-vm) do not install fnm and do not run its shell hook.

## Acceptance criteria

- desktop, server and dev-vm: no `fnm` package, and no `fnm env` in the fish or zsh init.
- macbook: `fnm` installed and `fnm env --use-on-cd` in its fish and zsh init.
- `nix fmt -- --ci` passes.

## Out of scope

- How Linux provides Node (Nix, direnv) — it works today.

## Constraints

None.

## Open questions

None.
~~~~

You would answer: nothing beyond the requirement.

Done means: for desktop, server and dev-vm, the evaluated home-manager config has no `fnm`
in its packages and no `fnm env` in fish or zsh init; for the macbook it has both; `nix fmt
-- --ci` exits 0.

## t02-power-menu-rows

~~~~markdown
# The power menu shows every row

## Goal

The rofi power menu shows all of its rows, so the Stay awake rows can be seen.

## Requirements

- `power-profile menu` lists the profiles, Auto, Suspend now and the Stay awake rows, but only 7 rows are visible, so the Stay awake rows are cut off. Every row the menu offers must be visible, however many there are.
- Other rofi menus stay as they are.

## Acceptance criteria

- With the idle stack on, all 11 rows are visible; with a Stay awake active, all 12; with the idle stack off, all 6.
- shellcheck passes on the script.

## Out of scope

- Changing the rofi theme of other menus.

## Constraints

None.

## Open questions

None.
~~~~

You would answer: nothing beyond the requirement.

Done means: the menu, run with a stub `rofi` in the three states, asks rofi to show at
least as many lines as rows it passes (11, 12, 6); the shared rofi config is unchanged;
`shellcheck` passes.

## t03-lazygit-jump

~~~~markdown
# lazygit number keys jump to the right panels

## Goal

In lazygit, 1 jumps to files.

## Requirements

- The number keys jump to panels in this order: 1 files, 2 branches, 3 commits, 4 stash, 0 status. Today 1 does not go to files.
- The number keys stay the only way to switch panels.

## Acceptance criteria

- In lazygit, pressing 1, 2, 3, 4 and 0 focuses files, branches, commits, stash and status.

## Out of scope

- Other lazygit key bindings.

## Constraints

None.

## Open questions

None.
~~~~

You would answer: nothing beyond the requirement.

Done means: the generated lazygit config maps the jump keys to status, files, branches,
commits, stash as 0, 1, 2, 3, 4; the previous/next panel keys are still disabled; lazygit
starts with the config without a config error.

## t04-ignore-worktrees

~~~~markdown
# Git ignores Claude Code worktrees everywhere

## Goal

`.claude/worktrees/` never shows up as untracked in any repo.

## Requirements

- Claude Code's per-agent worktree directories (`.claude/worktrees/`) show up as untracked files in every repo. Git must ignore them in every repo on every machine, without each repo adding it.

## Acceptance criteria

- In a new repo on any profile, a file under `.claude/worktrees/` is ignored by git.

## Out of scope

- Ignoring the rest of `.claude/` — repos commit their `.claude/settings.json` and skills.

## Constraints

None.

## Open questions

None.
~~~~

You would answer: nothing beyond the requirement.

Done means: with each profile's generated global git ignore file, `git check-ignore` in a
fresh repo ignores `.claude/worktrees/a/file` and does not ignore `.claude/settings.json`.

## t05-fish-keymaps

~~~~markdown
# Fish-style cursor keys in pi and opencode

## Goal

The input box of pi and opencode moves the cursor with the same keys as my fish shell.

## Requirements

- ctrl+n moves one word back, ctrl+e one word forward, ctrl+o to the end of the line, the same as in fish.nix.
- ctrl+a (line start) and ctrl+w (delete word) keep working.
- The keys that move the cursor today (alt+b, alt+f, ctrl+left, ctrl+right, …) keep working.
- Claude Code and the Cursor CLI are left as they are.

## Acceptance criteria

- In pi and in opencode, after typing a few words, ctrl+n, ctrl+e and ctrl+o move the cursor as fish does.

## Out of scope

- Claude Code and the Cursor CLI — they cannot rebind cursor movement.

## Constraints

None.

## Open questions

None.
~~~~

You would answer: if a key I asked for is already taken by another action, move model
select to alt+m and tool expand to alt+o. Anything else: you decide.

Done means: in the generated pi keybindings, word left, word right and line end include
ctrl+n, ctrl+e and ctrl+o and still include their default keys; model select is alt+m and
tool expand alt+o, and no other pi action keeps ctrl+n, ctrl+e or ctrl+o outside list
navigation; in the generated opencode config, word backward, word forward and line end
include ctrl+n, ctrl+e, ctrl+o and keep alt+b and alt+f; Claude's keybindings file is
unchanged.

## t06-z2m-permit-join

~~~~markdown
# Zigbee2MQTT permit-join-forever behind a flag

## Goal

The permit-join-forever extension only runs when I turn it on.

## Requirements

- A flag in the z2m feature options turns the permit-join-forever extension on. It is off unless a profile turns it on.
- With the flag off, a copy installed by an earlier activation stops loading too.
- No profile turns it on in this change.

## Acceptance criteria

- With the flag off, after activation `~/.homelab/z2m/external_extensions/permit_join_forever.js` does not exist, even when it existed before.
- With the flag on, after activation that file exists with the extension's content.
- After a rebuild of the homelab, Zigbee2MQTT no longer permits joins forever (checked on the homelab).

## Out of scope

- Other Zigbee2MQTT settings.

## Constraints

None.

## Open questions

None.
~~~~

You would answer: there is no access to the homelab from here; it is checked after the merge.

Done means: the activation script of the server profile, run against a temp data dir that
already holds the extension, removes it with the new flag off (the default) and installs it
with the flag on; no profile sets the flag; the PR lists the live homelab check as NOT RUN
instead of claiming it passed.

## t07-game-watcher-cpu

~~~~markdown
# The game watcher stops burning CPU

## Goal

power-watch costs next to nothing while it polls, and stops logging write errors.

## Requirements

- power-watch uses about 1.4 s of CPU per minute on the desktop, with about 490 processes running. It polls every 2 s. It must use a small fraction of that, with the same 2 s poll.
- The journal shows `power-watch: line 130: echo: write error: Broken pipe`. That must not happen any more.
- Game detection works as today: Steam games (they run under `reaper SteamLaunch AppId=<id>`) and the named apps, only processes I own.

## Acceptance criteria

- With about 500 processes running, power-watch uses well under 300 ms of CPU per 60 s.
- A Steam game is picked up within one poll after it starts and dropped after it exits; the same for a named app.
- No write errors from power-watch during those checks, with a Steam setup like the desktop's (two Steam roots, several libraries).

## Out of scope

- The power profiles themselves, and what a detected game switches to.

## Constraints

- No new runtime dependencies for the watcher.

## Open questions

None.
~~~~

You would answer: nothing beyond the requirement.

Done means: power-watch runs 60 s next to 500 processes and a fake Steam game and a fake
named app, using under 300 ms of CPU (to be calibrated: the base commit must fail it and
the merged fix pass it); each game appears in the games file within one poll of starting
and leaves it after exiting; a process owned by another user is not picked up; nothing is
written to stderr with two Steam roots and several libraries.

## t08-offline-search

~~~~markdown
# Search the notes site

## Goal

The notes site has a working search box that needs no external service.

## Requirements

- The site has no way to search notes. With 247 docs, finding a note means browsing the sidebar. Add offline, local full-text search so the navbar has a working search box on the GitHub Pages build.
- No external service: no Algolia account, no crawler, no CI secret.

## Acceptance criteria

- A search box in the navbar on every page.
- Searching returns matching notes and blog posts, and links to the right heading.
- Works in the `pnpm build` + `pnpm serve` output.
- The search index builds in CI without new secrets.

## Out of scope

- Search analytics, and search over pages outside docs and blog.

## Constraints

None.

## Open questions

None.
~~~~

You would answer: a new npm dependency (a search plugin) is fine. Anything else: you decide.

Done means: against `pnpm build` and `pnpm serve` of the branch, with no environment
secrets: a search box is in the navbar on three different pages; a phrase from a doc
heading finds that doc, and opening the result lands on that heading's anchor; a phrase
from the blog post finds it; no request leaves localhost while searching.

## t09-tel-links

~~~~markdown
# Tap-to-call contact numbers

## Goal

On the Coconut Cultivation Contacts page, tapping a phone number on my phone starts a call.

## Requirements

- Every phone number in the contacts table is a link that dials that number.
- The numbers look the same as now, for example `+94 704 001 928`.

## Acceptance criteria

- On the built site, each phone number on the Contacts page is a `tel:` link to the full international number, and its visible text is unchanged.

## Out of scope

- Other pages.

## Constraints

None.

## Open questions

None.
~~~~

You would answer: nothing beyond the requirement.

Done means: in the built Contacts page, every phone number from the base commit's table is
inside a link whose `href` is `tel:` plus the number's digits with the leading `+94`, its
text is unchanged, and the rest of the table is unchanged; `pnpm build` passes.

## t10-dap-attach

~~~~markdown
# Attaching the Java debugger works

## Goal

I can attach the Java debugger to a JVM that is already running.

## Requirements

- Every Java debug configuration with `request = "attach"` (host and port) fails with "To enrich the config, mainClass should already be present", unless I fill in dummy values for mainClass, projectName, modulePaths, classPaths and javaExec. Attach configurations must work without them: the JVM is already running and chose its own.
- Launch configurations keep working as today.

## Acceptance criteria

- Starting a debug session with an attach configuration that has no mainClass gets past that error and reaches the debug adapter.
- Launch configurations are still filled in as today: main class, project, class and module paths, java executable.

## Out of scope

- Other debug adapter features.

## Constraints

None.

## Open questions

None.
~~~~

You would answer: nothing beyond the requirement.

Done means: in headless Neovim with the plugin and a stub Java debug client, the debug
adapter's config hook accepts an attach config with no mainClass, passes it on, and never
asks the stub to resolve a main class or classpath; a launch config with a mainClass is
still filled in from the stub; a launch config with no mainClass still fails as before.
