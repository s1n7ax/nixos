{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        name = "Self Hosted";
        bookmarks = [
          {
            name = "Home Assistant";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:8124";
          }
          {
            name = "Frigate";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:8971";
          }
          {
            name = "Portainer";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:9000/";
          }
          {
            name = "Jellifin";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:8000/";
          }
          {
            name = "qBittorrent";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.111:8001/";
          }
          {
            name = "Radarr Movies";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:7878/";
          }
          {
            name = "Sonarr TV";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:8989/";
          }
          {
            name = "Prowlarr";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:9696/";
          }
          {
            name = "Lidarr - Music";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:8686/";
          }
          {
            name = "Ad Guard";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:3000/";
          }
          {
            name = "Grafana";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:3001/dashboards/";
          }
        ];
      }
    ];
  };
}
