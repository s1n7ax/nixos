{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        name = "Zigbee";
        bookmarks = [
          {
            name = "zigbee2mqtt devices";
            tags = [
              "zigbee"
              " device"
            ];
            url = "https://www.zigbee2mqtt.io/supported-devices/";
          }
          {
            name = "Zigbee device list";
            tags = [
              "zigbee"
              "device"
            ];
            url = "https://zigbee.blakadder.com/";
          }

        ];
      }
      {
        name = "Development";
        bookmarks = [
          {
            name = "Component Party";
            tags = [
              "frontend"
              "framework"
            ];
            url = "https://component-party.dev/";
          }
          {
            name = "Typescript Playground";
            tags = [
              "typescript"
            ];
            url = "https://www.typescriptlang.org/play/";
          }
        ];
      }
      {
        name = "Other";
        bookmarks = [
          {
            name = "localhost";
            tags = [ "local" ];
            url = "http://localhost:3000";
          }
          {
            name = "localhost";
            tags = [ "local" ];
            url = "http://localhost:5173";
          }
          {
            name = "supabase local";
            tags = [ "local" ];
            url = "http://127.0.0.1:54323";
          }
          {
            name = "tailwind";
            tags = [ "css" ];
            url = "https://nerdcave.com/tailwind-cheat-sheet";
          }
          {
            name = "docusaurus";
            tags = [ "docs" ];
            url = "https://docusaurus.io";
          }
          {
            name = "presenterm";
            tags = [ "docs" ];
            url = "https://mfontanini.github.io/presenterm";
          }
        ];
      }
    ];
  };
}
