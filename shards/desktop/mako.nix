{ config, ... }:

let
  inherit (config.caldera.user) login;
in
{
  home-manager.users.${login} = _: {
    services.mako = {
      enable = true;
      settings = {
        default-timeout = 5000;
        border-radius = 8;
      };
    };
  };
}
