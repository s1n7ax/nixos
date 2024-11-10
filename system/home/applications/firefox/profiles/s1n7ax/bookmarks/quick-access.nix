{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = [
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
      ];
    }
  ];
}
