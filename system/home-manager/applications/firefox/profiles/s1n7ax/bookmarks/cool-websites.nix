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
          {
            name = "Design";
            bookmarks = [
              {
                name = "Backgrounds";
                tags = [
                  "ui"
                  "design"
                ];
                url = "https://bg.ibelick.com/";
              }
              {
                name = "Gradient Generator";
                tags = [
                  "ui"
                  "design"
                ];
                url = "https://www.joshwcomeau.com/gradient-generator/";
              }
            ];
          }
        ];
      }
    ];
  };
}
