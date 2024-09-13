{ ... }:
{
  programs.firefox = {
    profiles.work = {
      id = 0;
      name = "Work Profile";
      search = {
        force = true;
        default = "DuckDuckGo";
        privateDefault = "DuckDuckGo";
      };
    };
    policies = {
      ExtensionSettings = {
        "extension@redux.devtools" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/reduxdevtools/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };
}
