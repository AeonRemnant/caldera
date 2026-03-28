{ config, inputs, ... }:

let
  inherit (config.caldera.user) login;
in
{
  home-manager.users.${login} =
    { ... }:
    {
      imports = [ inputs.zen-browser.homeModules.twilight ];
      programs.zen-browser.enable = true;
    };
}
