{
  config,
  lib,
  pkgs,
  ...
}:
let
  data_path = "${config.home.homeDirectory}/.homelab/homepage";

  # Homepage configuration files
  settingsYaml = pkgs.writeText "settings.yaml" ''
    ---
    title: "Homelab Dashboard"
    subtitle: "s1n7ax's Services"
    logo: https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/homepage.png
    headerStyle: clean
    hideVersion: true

    layout:
      Entertainment:
        style: row
        columns: 3
      Home Automation:
        style: row
        columns: 2
      Network & Security:
        style: row
        columns: 2
      System:
        style: row
        columns: 3

    theme: dark
    color: slate
    language: en

    quicklaunch:
      searchDescriptions: true
      hideInternetSearch: true
      hideVisitURL: true

    background:
      image: https://images.unsplash.com/photo-1451187580459-43490279c0fa?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2072&q=80
      blur: sm
      saturate: 50
      brightness: 50
      opacity: 50

    customCSS: |
      .service-group {
        border-radius: 15px;
      }
      
      .service-card {
        backdrop-filter: blur(10px);
        background: rgba(255, 255, 255, 0.1);
        border: 1px solid rgba(255, 255, 255, 0.2);
      }
  '';

  servicesYaml = pkgs.writeText "services.yaml" ''
    ---
    - Entertainment:
        - Jellyfin:
            href: http://192.168.1.110:8096
            icon: jellyfin.png
            description: Media Server
            server: 192.168.1.110;
            container: jellyfin
            widget:
              type: jellyfin
              url: http://192.168.1.110:8096
              key: {{HOMEPAGE_VAR_JELLYFIN_KEY}}

        - Sonarr:
            href: http://192.168.1.110:8989
            icon: sonarr.png
            description: TV Series Management
            server: 192.168.1.110
            container: sonarr
            widget:
              type: sonarr
              url: http://192.168.1.110:8989
              key: {{HOMEPAGE_VAR_SONARR_KEY}}

        - Radarr:
            href: http://192.168.1.110:7878
            icon: radarr.png
            description: Movie Management
            server: 192.168.1.110
            container: radarr
            widget:
              type: radarr
              url: http://192.168.1.110:7878
              key: {{HOMEPAGE_VAR_RADARR_KEY}}

        - Prowlarr:
            href: http://192.168.1.110:9696
            icon: prowlarr.png
            description: Indexer Manager
            server: 192.168.1.110
            container: prowlarr
            widget:
              type: prowlarr
              url: http://192.168.1.110:9696
              key: {{HOMEPAGE_VAR_PROWLARR_KEY}}

        - qBittorrent:
            href: http://192.168.1.110:8080
            icon: qbittorrent.png
            description: Torrent Client
            server: 192.168.1.110
            container: qbittorrent
            widget:
              type: qbittorrent
              url: http://192.168.1.110:8080
              username: {{HOMEPAGE_VAR_QBITTORRENT_USER}}
              password: {{HOMEPAGE_VAR_QBITTORRENT_PASS}}

    - Home Automation:
        - Home Assistant:
            href: http://192.168.1.110:8124
            icon: home-assistant.png
            description: Home Automation Hub
            server: 192.168.1.110
            container: home-assistant
            widget:
              type: homeassistant
              url: http://192.168.1.110:8124
              key: {{HOMEPAGE_VAR_HOMEASSISTANT_KEY}}

        - Frigate:
            href: http://192.168.1.110:8971
            icon: frigate.png
            description: Security Camera System
            server: 192.168.1.110
            container: frigate
            widget:
              type: frigate
              url: http://192.168.1.110:8971

        - Zigbee2MQTT:
            href: http://192.168.1.110:8080
            icon: zigbee2mqtt.png
            description: Zigbee Bridge
            server: 192.168.1.110
            container: z2m

    - Network & Security:
        - AdGuard Home:
            href: http://192.168.1.110:3000
            icon: adguard-home.png
            description: DNS Filter & DHCP
            server: 192.168.1.110
            container: adguard
            widget:
              type: adguardhome
              url: http://192.168.1.110:3000
              username: {{HOMEPAGE_VAR_ADGUARD_USER}}
              password: {{HOMEPAGE_VAR_ADGUARD_PASS}}

        - MQTT Broker:
            icon: mqtt.png
            description: Message Broker (Mosquitto)
            server: 192.168.1.110
            container: mqtt

    - System:
        - Portainer:
            href: http://192.168.1.110:9000
            icon: portainer.png
            description: Container Management
            widget:
              type: portainer
              url: http://192.168.1.110:9000
              env: 1
              key: {{HOMEPAGE_VAR_PORTAINER_KEY}}

        - Grafana:
            href: http://192.168.1.110:3001
            icon: grafana.png
            description: Monitoring Dashboard
            widget:
              type: grafana
              url: http://192.168.1.110:3001
              username: {{HOMEPAGE_VAR_GRAFANA_USER}}
              password: {{HOMEPAGE_VAR_GRAFANA_PASS}}

        - System Monitor:
            icon: glances.png
            description: System Resources
            widget:
              type: glances
              url: http://192.168.1.110:61208
  '';

  widgetsYaml = pkgs.writeText "widgets.yaml" ''
    ---
    - logo:
        icon: https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/homepage.png

    - search:
        provider: google
        target: _blank

    - greeting:
        text_size: xl
        text: "Welcome to your Homelab!"

    - datetime:
        text_size: l
        format:
          timeStyle: short
          dateStyle: short
          hourCycle: h23

    - openmeteo:
        label: Weather
        latitude: 6.9271
        longitude: 79.8612
        timezone: Asia/Colombo
        units: metric
        cache: 5

    - resources:
        label: System Resources
        cpu: true
        memory: true
        disk: /
        expanded: true
        diskUnits: bytes

    - unifi_console:
        url: http://192.168.1.110:8443
        username: {{HOMEPAGE_VAR_UNIFI_USER}}
        password: {{HOMEPAGE_VAR_UNIFI_PASS}}

    - glances:
        url: http://192.168.1.110:61208
        version: 4
        metric: cpu
  '';

  bookmarksYaml = pkgs.writeText "bookmarks.yaml" ''
    ---
    - Development:
        - GitHub:
            - href: https://github.com/s1n7ax
              icon: github.png
              description: Personal Repositories

        - Documentation:
            - href: https://nixos.org
              icon: nixos.png
              description: NixOS Documentation
            - href: https://home-manager-options.extranix.com
              icon: home-manager.png
              description: Home Manager Options

    - Homelab:
        - Docker Hub:
            - href: https://hub.docker.com
              icon: docker.png
              description: Container Images
        - LinuxServer.io:
            - href: https://docs.linuxserver.io
              icon: linuxserver.png
              description: Container Documentation

    - Utilities:
        - Speedtest:
            - href: https://fast.com
              icon: netflix.png
              description: Internet Speed Test
        - Pi-hole Blocklists:
            - href: https://firebog.net
              icon: pihole.png
              description: DNS Blocklists
  '';

in
with lib;
{
  config = mkIf config.features.homelab.homepage.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/homepage 0700 - - -"
      "d %h/.homelab/homepage/config 0700 - - -"
    ];

    services.podman.networks.homepage-network = {
      autoStart = true;
      driver = "bridge";
    };

    services.podman.containers.homepage = {
      image = "ghcr.io/gethomepage/homepage:latest";
      network = [ "homepage-network" ];

      volumes = [
        "${data_path}/config:/app/config"
        # "/run/user/1000/podman/podman.sock:/var/run/docker.sock:ro" # optional, for container integrations
        "${settingsYaml}:/app/config/settings.yaml:ro"
        "${servicesYaml}:/app/config/services.yaml:ro"
        "${widgetsYaml}:/app/config/widgets.yaml:ro"
        "${bookmarksYaml}:/app/config/bookmarks.yaml:ro"
      ];

      ports = [ "3001:3000" ];

      environment = {
        HOMEPAGE_ALLOWED_HOSTS = "192.168.1.110:3001,localhost:3001,gethomepage.dev";
        PUID = "1000";
        PGID = "1000";
      };

      autoStart = true;
    };
  };
}

