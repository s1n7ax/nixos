{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        name = "Tools";
        bookmarks = [
          {
            name = "ChatGPT";
            tags = [ "AI" ];
            url = "https://chatgpt.com/";
          }
          {
            name = "OpenUnicodeConverter";
            tags = [ "unicode" ];
            url = "https://www.sinhalaunicode.org/";
          }
          {
            name = "Adobe Express";
            tags = [ "editor" ];
            url = "https://express.adobe.com/";
          }
          {
            name = "Drawing";
            tags = [ "notes" ];
            url = "https://excalidraw.com/";
          }
        ];
      }
      {
        name = "Other";
        bookmarks = [
          {
            name = "DigitalOcean";
            tags = [ "digitalocean" ];
            url = "https://cloud.digitalocean.com/projects/b289809c-5802-4b1a-984a-48e352fb87ac";
          }
          {
            name = "Tailwind";
            tags = [ "css" ];
            url = "https://tailwindcss.com/";
          }
          {
            name = "IRD";
            tags = [ "IRD" ];
            url = "https://eservices.ird.gov.lk/Dashboard/ShowDashboard";
          }
          {
            name = "Dygma";
            tags = [ "keyboard" ];
            url = "https://dygma.com";
          }
        ];
      }
    ];
  };
}
