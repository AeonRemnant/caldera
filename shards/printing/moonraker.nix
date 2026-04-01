{ config, ... }:

{
  # Moonraker runs as its own user but needs access to /run/klipper/api
  users.groups.klipper = { };

  services.moonraker = {
    enable = true;
    address = "127.0.0.1";
    port = 7125;
    group = "klipper";
    settings = {
      authorization = {
        cors_domains = [
          "http://mainsail.${config.caldera.hostname}.lab"
          "http://10.1.1.174"
        ];
        trusted_clients = [
          "127.0.0.1/32"
          "192.168.0.0/16"
          "10.0.0.0/8"
        ];
      };
      octoprint_compat = { };
      history = { };
    };
  };
}
