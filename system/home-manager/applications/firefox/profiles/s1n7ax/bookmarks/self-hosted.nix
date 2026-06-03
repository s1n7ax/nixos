{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        name = "Homelab";
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
            url = "http://192.168.1.110:8001/";
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
          {
            name = "Node-RED";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:1880/";
          }
          {
            name = "Deye local";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.112/";
          }
          {
            name = "Backyard Shower Cam";
            tags = [ "camera" ];
            url = "http://192.168.1.121";
          }
          {
            name = "Backyard Roof Cam";
            tags = [ "camera" ];
            url = "http://192.168.1.122";
          }
          {
            name = "House Front Kitchen Cam";
            tags = [ "camera" ];
            url = "http://192.168.1.123";
          }
          {
            name = "House Front Road Cam";
            tags = [ "camera" ];
            url = "http://192.168.1.124";
          }
          {
            name = "TP-Link Extender";
            tags = [ "router" ];
            url = "http://192.168.1.130";
          }
          {
            name = "Solarman Logger";
            tags = [ "solar" ];
            url = "http://192.168.1.131";
          }
        ];
      }
    ];
  };
}
