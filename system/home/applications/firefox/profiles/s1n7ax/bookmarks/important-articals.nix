{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = [
    {
      name = "Important Articals";
      bookmarks = [
        {
          name = "WireGuard";
          bookmarks = [
            {
              name = "WireGuard Hub and Spoke Configuration";
              url = "https://www.procustodibus.com/blog/2020/11/wireguard-hub-and-spoke-config/";
            }
          ];
        }
      ];
    }
  ];
}
