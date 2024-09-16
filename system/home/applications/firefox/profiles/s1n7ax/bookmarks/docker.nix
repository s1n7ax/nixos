{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = [
    {
      name = "GitHub";
      bookmarks = [
        {
          name = "Docker Compose";
          bookmarks = [
            {
              name = "Composerize";
              tags = [ "docker-compose" ];
              url = "https://composerize.com/";
            }
            {
              name = "Docker Compose Documentation";
              tags = [
                "docker-compose"
                "documentation"
              ];
              url = "https://docs.docker.com/reference/compose-file/services/";
            }
          ];
        }
      ];
    }
  ];
}
