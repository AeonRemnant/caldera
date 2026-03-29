{ config, pkgs, ... }:

let
  inherit (config.caldera.user) login;
in
{
  # Removable media auto-mounting
  services.udisks2.enable = true;

  # KDE file management
  home-manager.users.${login} = _: {
    home.packages = with pkgs; [
      kdePackages.dolphin
      kdePackages.dolphin-plugins
      kdePackages.kio-extras
      kdePackages.breeze-icons
      kdePackages.kde-cli-tools
      kdePackages.qtwayland
    ];

    # Auto-mount removable media with tray icon
    services.udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "auto";
    };
  };
}
