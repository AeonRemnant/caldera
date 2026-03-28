{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.caldera) user;
in
{
  users.users.${user.login} = {
    isNormalUser = true;
    description = user.name;
    extraGroups = user.groups;
    shell = pkgs.nushell;
    ignoreShellProgramCheck = true;
    # Set password on first login: passwd
    initialPassword = "caldera";
  };

  home-manager.users.${user.login} = _: {
    home = {
      inherit (config.caldera) stateVersion;
      username = user.login;
      homeDirectory = "/home/${user.login}";
      sessionVariables = {
        XDG_DATA_DIRS = "$HOME/.nix-profile/share:$XDG_DATA_DIRS";
        SUDO_ASKPASS = lib.getExe pkgs.lxqt.lxqt-openssh-askpass;
      };
    };

    xdg = {
      enable = true;
      mimeApps = {
        enable = true;
        defaultApplications = {
          "x-scheme-handler/http" = [ "zen-twilight.desktop" ];
          "x-scheme-handler/https" = [ "zen-twilight.desktop" ];
          "text/html" = [ "zen-twilight.desktop" ];
        };
      };
    };
  };
}
