{
  caldera = {
    hostname = "caldera";
    stateVersion = "25.11";

    user = {
      login = "operator";
      name = "Operator";
      git = {
        name = "operator";
        email = "operator@caldera.local";
      };
      groups = [
        "networkmanager"
        "wheel"
        "video"
        "input"
        "dialout" # Serial access for Klipper
      ];
    };

    timezone = "Australia/Brisbane";
    locale = "en_AU.UTF-8";
    gpu = "nvidia";

    wifi.enable = true;

    printer = {
      serial = "/dev/ttyUSB0";
      configDir = "/var/lib/klipper";
    };
  };
}
