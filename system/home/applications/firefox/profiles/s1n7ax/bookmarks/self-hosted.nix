{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = [
    {
      name = "Self Hosted";
      bookmarks = [
        {
          name = "Home Assistant";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:8123/onboarding.html";
        }
        {
          name = "Portainer";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:9000/";
        }
        {
          name = "Jellifin";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:8000/";
        }
        {
          name = "qBittorrent";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:8001/";
        }
        {
          name = "Radarr Movies";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:7878/";
        }
        {
          name = "Sonarr TV";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:8989/";
        }
        {
          name = "Prowlarr";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:9696/";
        }
        {
          name = "Lidarr - Music";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:8686/";
        }
        {
          name = "Ad Guard";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:3000/";
        }
        {
          name = "Grafana";
          tags = [ "self-hosted" ];
          url = "http://192.168.1.111:3001/";
        }
      ];
    }
  ];
}
