{ config, pkgs, ... }:

let
  inherit (config.caldera.user) login;
  dotfiles = config.caldera.dotfilesDir;
in
{
  # Register nushell as a valid login shell in /etc/shells
  # (required for PAM pam_shells.so to accept TTY logins)
  environment.shells = [ pkgs.nushell ];

  home-manager.users.${login} = _: {
    programs.nushell = {
      enable = true;
      extraConfig = builtins.readFile (dotfiles + "/nushell/config.nu");
      extraEnv = ''
        # Bridge home-manager session variables into nushell
        let hm_sess = ($env.HOME + "/.nix-profile/etc/profile.d/hm-session-vars.sh")
        if ($hm_sess | path exists) {
          let base = (^bash -c 'env -0' | split row (char nul) | where { $in != "" })
          let after = (^bash -c $'unset __HM_SESS_VARS_SOURCED; source "($hm_sess)"; env -0' | split row (char nul) | where { $in != "" })
          let base_path = ($base | where { $in starts-with "PATH=" } | get 0? | default "PATH=" | str replace "PATH=" "" | split row ':')
          for entry in ($after | where { $in not-in $base }) {
            let key = ($entry | split row '=' | first)
            let val = ($entry | str substring (($key | str length) + 1)..)
            if $key == "PATH" {
              let new_paths = ($val | split row ':' | where { $in not-in $base_path and $in != "" })
              if ($new_paths | length) > 0 {
                $env.PATH = ($new_paths | append $env.PATH)
              }
            } else if $key not-in ["__HM_SESS_VARS_SOURCED" "_" "SHLVL"] {
              load-env { ($key): ($val) }
            }
          }
        }
      '';
    };

    programs.zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };

    programs.starship = {
      enable = true;
      enableNushellIntegration = true;
    };

    # Functions directory (not managed by nushell module)
    home.file.".config/nushell/functions" = {
      source = dotfiles + "/nushell/functions";
      recursive = true;
      force = true;
    };

    # Packages used by aliases and scripts
    home.packages = with pkgs; [
      eza
      nix-output-monitor
    ];
  };
}
