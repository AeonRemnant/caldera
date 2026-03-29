{
  config,
  lib,
  ...
}:

let
  cfg = config.caldera.wifi;
in
{
  config = lib.mkIf cfg.enable {
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";

    sops.secrets."wifi_ssid" = {
      sopsFile = cfg.secretsFile;
    };
    sops.secrets."wifi_psk" = {
      sopsFile = cfg.secretsFile;
    };

    sops.templates."home-wifi.nmconnection" = {
      content = ''
        [connection]
        id=home-wifi
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
      path = "/etc/NetworkManager/system-connections/home-wifi.nmconnection";
      mode = "0600";
    };

    # Ensure secrets are decrypted before NetworkManager starts
    systemd.services.NetworkManager = {
      after = [ "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
    };
  };
}
