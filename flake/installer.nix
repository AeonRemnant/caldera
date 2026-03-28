{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;

      targetSystem = inputs.self.nixosConfigurations.caldera;

      installer = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          inputs.disko.nixosModules.disko

          (
            { lib, ... }:
            {
              networking = {
                hostName = "caldera-installer";
                wireless.enable = lib.mkForce false;
                networkmanager.enable = true;
              };

              nix.settings.experimental-features = [
                "nix-command"
                "flakes"
              ];

              # Pre-populate the nix store with the target system closure.
              # This allows nixos-install to work offline (or near-offline) since
              # almost all derivations are already present in the ISO's nix store.
              system.extraDependencies = [
                targetSystem.config.system.build.toplevel
              ];

              environment = {
                # Embed the Caldera flake source
                etc."caldera/flake".source = builtins.path {
                  path = ../.;
                  name = "caldera-flake";
                  filter =
                    path: _type:
                    let
                      base = baseNameOf path;
                    in
                    !builtins.elem base [
                      ".devenv"
                      ".direnv"
                      ".git"
                      "result"
                    ];
                };

                systemPackages =
                  (with pkgs; [
                    git
                    rsync
                    jq
                    btrfs-progs
                    dosfstools
                    nvme-cli
                    gptfdisk
                    inputs.disko.packages.${system}.disko
                  ])
                  ++ [
                    (pkgs.writeShellScriptBin "docs" "less ${pkgs.writeText "docs.txt" (builtins.readFile ../scripts/installer/docs.txt)}")
                    (pkgs.writeShellScriptBin "caldera-wipe" (builtins.readFile ../scripts/installer/wipe.sh))
                    (pkgs.writeShellScriptBin "caldera-install" (builtins.readFile ../scripts/installer/install.sh))
                  ];
              };
            }
          )
        ];
      };
    in
    {
      packages.installer-iso = installer.config.system.build.isoImage;
    };
}
