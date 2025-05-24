{ ... }:
{
  config.programs.firefox = {
    profiles.work = {
      name = "Work Profilee";
      search = {
        force = true;
        default = "ddg";
        privateDefault = "ddg";
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
