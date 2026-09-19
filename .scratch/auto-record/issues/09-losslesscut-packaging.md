# LosslessCut into the config

Type: task
Status: open

## Question

Add LosslessCut to `system/home-manager/applications/packages.nix` behind the existing `features.productivity.video-production.screen-capture` flag (the same flag that gates OBS today in `obs-studio/default.nix`).

- Confirm the nixpkgs attribute name and that it builds on this channel.
- Decide whether OBS and kdenlive stay declared at all once the pipeline replaces them — `kdePackages.kdenlive` is already commented out in `packages.nix:83`.

Resolved when the package is named and the removal question is answered. Record the attribute path in the answer.
