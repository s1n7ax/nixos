{ ... }:
{
  config.programs.firefox.profiles.s1n7ax = {
    name = "Personal Profile";
    search = {
      force = true;
      default = "ddg";
      privateDefault = "ddg";
    };
    settings = {
      # Stop Firefox adding the "Import Bookmarks…" button to the toolbar
      "browser.bookmarks.addedImportButton" = true;
    };
  };
}
