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

  # The Playwright MCP (Claude Code's playwright plugin) launches with a fixed
  # `--browser chromium`, which the bundled Playwright resolves to Google's
  # "chrome-for-testing" download - absent here, and not what we want anyway.
  # This wrapper is the executable Playwright launches instead: the open-source
  # Chromium above. The glob resolves the `chromium-<rev>` dir at runtime so a
  # driver bump does not need this path edited.
  chromium = pkgs-unstable.writeShellScript "playwright-mcp-chromium" ''
    exec ${browsers}/chromium-*/chrome-linux*/chrome "$@"
  '';
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
      # Env form of the MCP's `--executable-path`; overrides its `--browser
      # chromium` so Claude drives the open-source Chromium, not chrome-for-testing.
      PLAYWRIGHT_MCP_EXECUTABLE_PATH = "${chromium}";
    };
  };
}
