{ ... }:
{
  programs.firefox.profiles.work.bookmarks = {
    force = true;
    settings = [
      {
        toolbar = true;
        bookmarks = [ ];
      }
    ];
  };
}
