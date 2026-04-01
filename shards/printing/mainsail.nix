{ config, lib, ... }:

let
  domain = "mainsail.${config.caldera.hostname}.lab";
in
{
  services.mainsail = {
    enable = true;
    hostName = domain;
    nginx.extraConfig = "client_max_body_size 1000m;";
  };

  # Serve Mainsail for any Host header (IP access, mDNS, etc.)
  services.nginx.virtualHosts.${domain}.default = lib.mkForce true;
}
