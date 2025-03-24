{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        name = "GitHub";
        bookmarks = [
          {
            name = "Ileriayo/markdown-badges: Badges for your personal developer branding, profile, and projects.";
            url = "https://github.com/Ileriayo/markdown-badges";
          }
          {
            name = "Most active GitHub users in Sri Lanka";
            url = "https://committers.top/sri_lanka_public#s1n7ax";
          }
          {
            name = "Most active GitHub users in Sri Lanka";
            url = "https://committers.top/sri_lanka#s1n7ax";
          }
        ];
      }
    ];
  };
}
