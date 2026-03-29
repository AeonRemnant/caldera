{ lib, ... }:

{
  options.caldera = {
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "System hostname.";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "NixOS and Home Manager state version.";
    };

    user = {
      login = lib.mkOption {
        type = lib.types.str;
        description = "Primary user login name.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        description = "Primary user display name.";
      };

      git = {
        name = lib.mkOption {
          type = lib.types.str;
          description = "Git author name.";
        };

        email = lib.mkOption {
          type = lib.types.str;
          description = "Git author email.";
        };
      };

      groups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "networkmanager"
          "wheel"
          "video"
          "input"
        ];
        description = "Extra groups for the primary user.";
      };
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "System timezone.";
    };

    locale = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "System locale.";
    };

    gpu = lib.mkOption {
      type = lib.types.enum [
        "nvidia"
        "amd"
        "intel"
        "none"
      ];
      default = "none";
      description = "GPU driver to configure.";
    };

    disk = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Original target drive path (reference only, not used at runtime).";
    };

    dotfilesDir = lib.mkOption {
      type = lib.types.path;
      default = ../dotfiles;
      description = "Path to the dotfiles directory (nix store, read-only).";
    };

    printer = {
      serial = lib.mkOption {
        type = lib.types.str;
        default = "/dev/ttyUSB0";
        description = "Serial device for the 3D printer MCU.";
      };

      configDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/klipper";
        description = "Mutable directory for Klipper config (printer.cfg).";
      };
    };

    wifi = {
      enable = lib.mkEnableOption "encrypted WiFi credentials via sops-nix";

      secretsFile = lib.mkOption {
        type = lib.types.path;
        default = ../secrets/wifi.yaml;
        description = "Path to sops-encrypted WiFi credentials file.";
      };
    };
  };
}
