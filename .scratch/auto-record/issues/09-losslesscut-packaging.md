# LosslessCut into the config

Type: task
Status: resolved

## Question

Add LosslessCut to `system/home-manager/applications/packages.nix` behind the existing `features.productivity.video-production.screen-capture` flag (the same flag that gates OBS today in `obs-studio/default.nix`).

- Confirm the nixpkgs attribute name and that it builds on this channel.
- Decide whether OBS and kdenlive stay declared at all once the pipeline replaces them — `kdePackages.kdenlive` is already commented out in `packages.nix:83`.

Resolved when the package is named and the removal question is answered. Record the attribute path in the answer.

## Answer

**Attribute: `losslesscut`** (3.68.0 on `nixos-26.05`), added to `packages.nix` behind
`features.productivity.video-production.screen-capture.enable`.

Cached for `x86_64-linux` — 17.3 MB down, 68.3 MB unpacked — so it needs no local build. The
`nixosConfigurations.desktop` closure evaluates with it and pulls it plus `electron-42.5.1`
from `cache.nixos.org`.

Not `losslesscut-bin`: it is 3.64.0 on this channel, four minor versions behind, and the source
build is cached anyway, so the AppImage wrapper buys nothing here.

### OBS and kdenlive

- **`kdePackages.kdenlive` stays commented out.** It was already off at `packages.nix:83` and
  nothing in this route wants it back.
- **OBS stays declared, for now.** `record` has not yet recorded a real take — every number in
  it is measured, but the pipeline itself has only run against `testsrc2` and a preflight gate.
  Deleting the fallback before the replacement has been used once is the wrong order. Revisit
  after the first real take; either way that is repo tidying and not part of this route, exactly
  as the map already rules for `camera-connect`.
