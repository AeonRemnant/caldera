{ config, ... }:

{
  services.moonraker = {
    enable = true;
    address = "127.0.0.1";
    port = 7125;
    settings = {
      authorization = {
        cors_domains = [
          "http://mainsail.${config.caldera.hostname}.lab"
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
