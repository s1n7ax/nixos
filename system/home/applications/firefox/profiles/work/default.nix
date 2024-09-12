{ ... }:
{
  programs.firefox.profiles.work.search = {
    force = true;
    default = "DuckDuckGo";
    privateDefault = "DuckDuckGo";
  };
}
