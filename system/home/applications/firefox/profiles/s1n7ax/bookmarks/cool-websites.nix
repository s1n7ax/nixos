{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        name = "UI";
        bookmarks = [
          {
            name = "Components";
            bookmarks = [
              {
                name = "Aceternity";
                tags = [
                  "ui"
                  "components"
                ];
                url = "https://ui.aceternity.com/";
              }
            ];
          }
        ];
      }
    ];
  };
}
