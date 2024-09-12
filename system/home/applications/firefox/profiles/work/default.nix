{ ... }:
{
  programs.firefox.profiles.work = {
    id = 1;
    name = "Work Profile";
    search = {
      force = true;
      default = "DuckDuckGo";
      privateDefault = "DuckDuckGo";
    };
  };
}
