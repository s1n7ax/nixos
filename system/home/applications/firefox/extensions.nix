{ ... }:
{
  # ---- EXTENSIONS ----
  # Check about:support for extension/add-on ID strings.
  # Valid strings for installation_mode are "allowed", "blocked",
  # "force_installed" and "normal_installed".
  programs.firefox.policies.ExtensionSettings = {
    "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
    # uBlock Origin:
    "uBlock0@raymondhill.net" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      installation_mode = "force_installed";
    };
    "addon@darkreader.org" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
      installation_mode = "force_installed";
    };
    "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
      installation_mode = "force_installed";
    };
    "firefox-compact-dark@mozilla.org" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
      installation_mode = "force_installed";
    };
    "{ddc62400-f22d-4dd3-8b4a-05837de53c2e}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/read-aloud/latest.xpi";
      installation_mode = "force_installed";
    };
  };
}
