{ ... }:
{
  programs.firefox.profiles.work = {
    id = 0;
    name = "Work Profile";
    search = {
      force = true;
      default = "DuckDuckGo";
      privateDefault = "DuckDuckGo";
    };
  };
}
