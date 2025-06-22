{ config, lib, pkgs, ... }:
let
  ip = config.sops.placeholder."wireguard/spoke_homelab/ip";
  port = config.sops.placeholder."wireguard/spoke_homelab/port";
  private_key = config.sops.placeholder."wireguard/spoke_homelab/private_key";
  preshared_key = config.sops.placeholder."wireguard/spoke_homelab/preshared_key";

  nginx_config = pkgs.writeText "nginx.conf" ''
    events {
      worker_connections	1024;
    }

    http {
      server_tokens off;
      charset utf-8;

      server {
        listen 8124;
        listen [::]:8124;
        server_name home-assistant;

        location / {
          proxy_pass http://host.containers.internal:8124;

          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          # proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;

          # Handle WebSocket connections, necessary for Home Assistant
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        }
      }
    }
  '';
in
with lib;
{
  config = mkIf config.features.homelab.wireguard.enable {
    networking.firewall.allowedUDPPorts = [ 51820 ];
    networking.firewall.trustedInterfaces = [ "wg0" ];

    virtualisation.quadlet =
    let
      inherit (config.virtualisation.quadlet) containers;
    in
    {
      containers.nginx = {
        autoStart = true;
        serviceConfig = {
          RestartSec = "30";
          Restart = "always";
        };
        unitConfig = {
          Requires = [ containers.wireguard.ref ];
          After = [ containers.wireguard.ref ];
        };
        containerConfig = {
          image = "docker.io/library/nginx:latest";
          networks = [ "container:wireguard" ];
          noNewPrivileges = true;
          volumes = [ "${nginx_config}:/etc/nginx/nginx.conf:ro" ];
        };
      };

      containers.wireguard = {
        autoStart = true;
        serviceConfig = {
          RestartSec = "30";
          Restart = "always";
        };
        containerConfig = {
          image = "lscr.io/linuxserver/wireguard:latest";
          addCapabilities = [
            "NET_ADMIN"
            "NET_RAW"
          ];
          environments = {
            PUID = "1000";
            PGID = "1000";
            TZ = "Etc/UTC";
          };
          sysctl = {
            "net.ipv4.conf.all.src_valid_mark" = "1";
          };
          volumes = [
            "${config.sops.templates."wg0.conf".path}:/config/wg_confs/wg0.conf"
          ];
          publishPorts = [ "51820:51820/udp" ];
        };
      };
    };

  sops.templates."wg0.conf" = {
    content = ''
      [Interface]
      Address = 10.0.0.2/32
      PrivateKey = ${private_key}
      ListenPort = 51820
      DNS = 10.0.0.1

      [Peer]
      PublicKey = dKIqkl8S34b5Gg4FfiThyZ69c7Rm5Y1Umwy8SRQM/zc=
      PresharedKey = ${preshared_key}
      Endpoint = ${ip}:${port}
      AllowedIPs = 0.0.0.0/0
      PersistentKeepalive = 25
    '';
    };
  };
}
