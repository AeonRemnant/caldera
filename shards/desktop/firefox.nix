{ config, ... }:

let
  inherit (config.caldera.user) login;
in
{
  programs.firefox.enable = true;

  home-manager.users.${login} = _: {
    programs.firefox.enable = true;
  };
}
