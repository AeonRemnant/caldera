{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;

      targetSystem = inputs.self.nixosConfigurations.caldera;

      # Age key for sops-nix secret decryption (optional — only embedded when present)
      ageKeyPath = ../keys/age.key;
      hasAgeKey = builtins.pathExists ageKeyPath;

      # SSH deploy key for private repo access
      sshKeyPath = ../keys/aeon;
      sshPubPath = ../keys/aeon.pub;
      hasSshKey = builtins.pathExists sshKeyPath;
      wifiSecretsPath = ../secrets/wifi.yaml;
      hasWifiSecrets = builtins.pathExists wifiSecretsPath;
      hasWifi = hasAgeKey && hasWifiSecrets;

      installer = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          inputs.sops-nix.nixosModules.sops

          (
            { config, lib, ... }:
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
              # nixos-install --system copies from here to the target disk.
              system.extraDependencies = [
                targetSystem.config.system.build.toplevel
              ];

              environment = {
                # Embed the Caldera flake source (for copying to target after install)
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
                      ".vm"
                      ".claude"
                      "result"
                      "keys"
                      "sda"
                    ];
                };

                # Store path to the pre-built system closure
                etc."caldera/system-closure".text = "${targetSystem.config.system.build.toplevel}";

                # Embed age key for sops-nix (if present at keys/age.key)
                etc."caldera/age.key" = lib.mkIf hasAgeKey {
                  source = ageKeyPath;
                  mode = "0600";
                };

                # Embed SSH deploy key for private repo access
                etc."caldera/aeon" = lib.mkIf hasSshKey {
                  source = sshKeyPath;
                  mode = "0600";
                };
                etc."caldera/aeon.pub" = lib.mkIf hasSshKey {
                  source = sshPubPath;
                  mode = "0644";
                };

                systemPackages =
                  (with pkgs; [
                    git
                    rsync
                    jq
                    btrfs-progs
                    dosfstools
                    smartmontools
                    gptfdisk
                  ])
                  ++ [
                    (pkgs.writeShellScriptBin "docs" "less ${pkgs.writeText "docs.txt" (builtins.readFile ../scripts/installer/docs.txt)}")
                    (pkgs.writeShellScriptBin "caldera-wipe" (builtins.readFile ../scripts/installer/wipe.sh))
                    (pkgs.writeShellScriptBin "caldera-install" (builtins.readFile ../scripts/installer/install.sh))
                  ];
              };

              # Auto-connect to WiFi if age key + encrypted credentials are present
              sops = lib.mkIf hasWifi {
                age.keyFile = "/etc/caldera/age.key";
                secrets."wifi_ssid".sopsFile = wifiSecretsPath;
                secrets."wifi_psk".sopsFile = wifiSecretsPath;
                templates."installer-wifi.nmconnection" = {
                  content = ''
                    [connection]
                    id=installer-wifi
                    uuid=b6d47cfe-4a08-4a4b-b53a-21f621a7bfa8
                    type=wifi
                    autoconnect=true

                    [wifi]
                    mode=infrastructure
                    ssid=${config.sops.placeholder."wifi_ssid"}
                    mtu=9000

                    [wifi-security]
                    key-mgmt=wpa-psk
                    psk=${config.sops.placeholder."wifi_psk"}

                    [ipv4]
                    method=manual
                    address1=10.1.1.174/21,10.0.0.1
                    dns=10.0.0.1;

                    [ipv6]
                    addr-gen-mode=default
                    method=auto
                  '';
                  path = "/etc/NetworkManager/system-connections/installer-wifi.nmconnection";
                  mode = "0600";
                };
              };

              systemd.services.NetworkManager = lib.mkIf hasWifi {
                after = [ "sops-nix.service" ];
                wants = [ "sops-nix.service" ];
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
