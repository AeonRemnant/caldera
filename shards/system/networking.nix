{ config, pkgs, ... }:

let
  inherit (config.caldera) hostname;
  inherit (config.caldera.user) login;
in
{
  networking = {
    networkmanager = {
      enable = true;
      wifi.powersave = false;
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        80 # Nginx (Mainsail)
      ];
    };
    # Local DNS for mainsail.<hostname>.lab
    hosts = {
      "127.0.0.1" = [ "mainsail.${hostname}.lab" ];
    };
  };

  home-manager.users.${login} = _: {
    home.packages = with pkgs; [
      networkmanagerapplet
    ];
  };
}
