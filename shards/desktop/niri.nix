{
  config,
  pkgs,
  inputs,
  ...
}:

let
  inherit (config.caldera.user) login;
in
{
  imports = [ inputs.niri.nixosModules.niri ];

  # XWayland support via xwayland-satellite (Niri has no built-in XWayland)
  # Screenshot tools: grim (capture) + slurp (region select) + wl-clipboard (clipboard)
  environment.systemPackages = [
    pkgs.xwayland-satellite
    pkgs.grim
    pkgs.slurp
    pkgs.wl-clipboard
    pkgs.swaybg
    pkgs.playerctl
    pkgs.polkit_gnome
  ];

  programs.niri.enable = true;
  programs.niri.package =
    inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-stable.overrideAttrs
      (_old: {
        doCheck = false;
      });

  # XDG Portals (compositor-specific)
  xdg.portal = {
    enable = true;
    configPackages = [ config.programs.niri.package ];
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    # Route FileChooser to gtk — gnome's implementation requires nautilus
    config.common."org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
  };

  # Link niri config from dotfiles
  home-manager.users.${login} = _: {
    home.file.".config/niri" = {
      source = config.caldera.dotfilesDir + "/niri";
      recursive = true;
      force = true;
    };
  };
}
