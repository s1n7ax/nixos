#!/usr/bin/env bash
# Install the repo's git hooks into .git/hooks.
#
# The user's global core.hooksPath (gitleaks) chains into
# .git/hooks/pre-commit, so we install there rather than overriding
# core.hooksPath.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
ln -sf ../../scripts/hooks/pre-commit "$repo_root/.git/hooks/pre-commit"
echo "Installed pre-commit hook -> scripts/hooks/pre-commit"
