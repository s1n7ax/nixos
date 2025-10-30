# Repository Guidelines

## Project Structure & Module Organization
This flake-driven repository centralizes entry points in `flake.nix`, which wires `nixosConfigurations` for each profile. Shared modules live under `profile/common`, while profile-specific overrides sit in `profile/<profile>/`. System-wide modules are grouped in `system/nixos/` (core, mounts, homelab, etc.), with user-facing home-manager modules under `system/home-manager/` and hardware definitions in `system/hardware/`. Keep new modules small and compose them through the relevant profile `configuration.nix`.

## Build, Test, and Development Commands
Use `nix flake update` to refresh inputs and keep `flake.lock` in sync. Validate changes with `nix flake check` before rebuilding. Build and switch a machine via `sudo nixos-rebuild switch --upgrade --flake ./#desktop` (swap `desktop` for another profile). For safer iteration run `nixos-rebuild test --flake ./#server` or `nixos-rebuild build --flake ./#desktop` to get derivations without switching. Apply user-level tweaks quickly with `home-manager switch --flake ./#desktop`. After major upgrades, free disk space with `sudo nix-collect-garbage -d`.

## Coding Style & Naming Conventions
Stick to two-space indentation inside Nix attrsets and prefer trailing semicolons per existing files. Name modules with lowercase-hyphenated filenames (`gpg.nix`, `env.nix`) and export options via explicit attrsets rather than `with`. When touching multiple attributes, group them logically and alphabetize where practical. Format before committing using `nixpkgs-fmt` (or `nix fmt` if you have it configured in your shell) and ensure generated files are excluded via `.gitignore`.

## Testing Guidelines
Every change should pass `nix flake check`; add new eval tests to `system/utils` when extending modules. Exercise system changes with `nixos-rebuild test --flake ./#<profile>` on the target hosts and prefer `nixos-rebuild build` for CI-style validation. For home-manager updates, run `home-manager switch --flake ./#<profile>` under a non-root session to confirm activation scripts.

## Commit & Pull Request Guidelines
Follow the Conventional Commits style already present (`feat:`, `chore:`, `refactor:`). Keep subject lines under 72 characters and describe scope when helpful (`feat(profile/desktop): add gpg agent`). Pull requests should summarize functional impact, list the profiles affected, link tracking issues, and include rebuild/test commands you executed. Attach screenshots or logs when UI or service changes are involved.

## Security & Secrets Handling
Secrets are sourced via the `inputs.secrets` flake and managed with `sops-nix`; never commit decrypted material. Edit secrets through `sops` and verify that corresponding `.sops.yaml` rules remain intact. When adding new services, place credentials in the secrets repository and reference them through the appropriate module option rather than hardcoding paths here.
