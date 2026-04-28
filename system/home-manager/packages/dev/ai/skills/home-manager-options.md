---
name: home-manager-options
description: Use when looking up available home-manager options, their types, defaults, or descriptions — e.g. "what options does programs.X expose", "how do I configure X in home-manager", or when unsure whether an option exists.
---

# Home-Manager Options

Run:

```bash
man home-configuration.nix | grep -C10 'programs.rclone'
```

Replace the pattern with the option path of interest. Adjust `-C10` up or down to widen or narrow the surrounding context.

## Why

The `home-configuration.nix` manpage is the authoritative, locally-installed source — faster and more accurate than a web search, and it matches the exact home-manager version on this system rather than whatever version the internet is talking about.
