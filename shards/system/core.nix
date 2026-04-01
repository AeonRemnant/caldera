{ config, pkgs, ... }:

{
  # === Bootloader ===
  boot.loader = {
    limine = {
      enable = true;
      efiSupport = true;
      maxGenerations = 5;
    };
    timeout = 1;
    efi.canTouchEfiVariables = true;
  };

  # === Nix Settings ===
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
    accept-flake-config = false;
    warn-dirty = false;
    auto-optimise-store = true;
    substituters = [
      "https://cache.nixos.org/"
      "https://niri.cachix.org"
      "https://vicinae.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
    ];
  };

  nixpkgs.config.allowUnfree = true;
  programs.command-not-found.enable = false;
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep 5 --keep-since 3d";
    };
    flake = "/config";
  };

  # === Base System Configuration ===
  time.timeZone = config.caldera.timezone;
  i18n.defaultLocale = config.caldera.locale;

  environment = {
    sessionVariables.NIXOS_OZONE_WL = "1";

    systemPackages = with pkgs; [
      coreutils-full
      git
      just
      wget
      tree
      btrfs-progs
      xdg-utils
      unzip
      jq
      upower
      ghostty
    ];
  };

  # Allow root (nixos-rebuild) and all users to access the /config repo
  environment.etc."gitconfig".text = ''
    [safe]
      directory = /config
  '';

  services = {
    dbus.enable = true;
    upower.enable = true;
  };
}
