{
  config,
  lib,
  ...
}:

let
  inherit (config.caldera.user) login;
in
{
  # Fix NVIDIA hardware cursor bug in cage (regreet's compositor)
  systemd.services.greetd.environment = lib.mkIf (config.caldera.gpu == "nvidia") {
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  programs.regreet = {
    enable = true;
    cageArgs = [
      "-s"
      "-m"
      "last"
    ];
    settings = {
      appearance.greeting_msg = "Welcome to Caldera";
    };
  };

  # Pre-seed regreet state to default to Niri for the primary user
  environment.etc."greetd/regreet-state.toml".text = ''
    last_user = "${login}"

    [user_sessions]
    ${login} = "niri-session"
  '';

  systemd.tmpfiles.rules = [
    "C /var/lib/regreet/state.toml 0600 greeter greeter - /etc/greetd/regreet-state.toml"
  ];
}
