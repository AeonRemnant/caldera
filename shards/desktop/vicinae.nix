{
  config,
  inputs,
  ...
}:

let
  inherit (config.caldera.user) login;
in
{
  home-manager.users.${login} =
    { ... }:
    {
      imports = [ inputs.vicinae.homeManagerModules.default ];

      services.vicinae = {
        enable = true;
        systemd.enable = true;
      };
    };
}
