{
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  # Playwright's own Chromium build, wrapped in the directory layout Playwright
  # expects. This is what `npx playwright install` would fetch, except that
  # download is dynamically linked and does not run on NixOS. It ships
  # open-source Chromium only - never Google Chrome. Unstable tracks a newer
  # Playwright release, closer to what `@playwright/mcp@latest` bundles, so the
  # Chromium revision is more likely to match.
  browsers = pkgs-unstable.playwright-driver.browsers;
in
{
  config = lib.mkIf config.features.development.playwright.enable {
    home.packages = [ browsers ];

    home.sessionVariables = {
      # Point Playwright - including the Playwright MCP - at the nix-store
      # Chromium instead of the per-user download dir it cannot populate here.
      PLAYWRIGHT_BROWSERS_PATH = "${browsers}";
      # `playwright install-deps` shells out to apt, which does not exist on NixOS.
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    };
  };
}
