{ ... }:
{
  # ---- EXTENSIONS ----
  # Check about:debugging#/runtime/this-firefox or about:support for extension/add-on ID strings.
  # Valid strings for installation_mode are "allowed", "blocked",
  # "force_installed" and "normal_installed".
  programs.firefox.policies.ExtensionSettings = {
    "*".installation_mode = "blocked"; # blocks all addons except the ones specified below

    # Dark theme
    "firefox-compact-dark@mozilla.org" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
      installation_mode = "force_installed";
    };

    # ublock
    "uBlock0@raymondhill.net" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      installation_mode = "force_installed";
    };

    # Dark Reader
    "addon@darkreader.org" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
      installation_mode = "force_installed";
    };

    # Vimium
    "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
      installation_mode = "force_installed";
    };

    # Read Aloud
    "{ddc62400-f22d-4dd3-8b4a-05837de53c2e}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/read-aloud/latest.xpi";
      installation_mode = "force_installed";
    };

    # React Devtools
    "@react-devtools" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/react-devtools/latest.xpi";
      installation_mode = "force_installed";
    };

    # Svelte Devtools
    "{a0370179-acc3-452f-9530-246b6adb2768}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/svelte-devtools/latest.xpi";
      installation_mode = "force_installed";
    };

  };
}
