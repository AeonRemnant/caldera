{ config, pkgs, ... }:

let
  hostname = config.caldera.hostname;
  domain = "mainsail.${hostname}.lab";
in
{
  # Mainsail frontend served by Caddy (NOT the default nginx module)
  services.caddy = {
    enable = true;
    virtualHosts.${domain} = {
      extraConfig = ''
        root * ${pkgs.mainsail}/share/mainsail
        file_server

        @api path /api/* /printer/* /server/* /machine/* /access/*
        handle @api {
          reverse_proxy 127.0.0.1:7125
        }

        handle /websocket {
          reverse_proxy 127.0.0.1:7125
        }

        handle /webcam/* {
          reverse_proxy 127.0.0.1:8080
        }
      '';
    };
  };

  # Caddy runs on port 80 — disable HTTPS for local .lab domain
  services.caddy.globalConfig = ''
    auto_https off
  '';
}
