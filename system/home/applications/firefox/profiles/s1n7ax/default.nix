{ ... }:
{
  programs.firefox.profiles.s1n7ax = {
    id = 1;
    name = "Personal Profile";
    search = {
      force = true;
      default = "DuckDuckGo";
      privateDefault = "DuckDuckGo";
    };
  };
}
