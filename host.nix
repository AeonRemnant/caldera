{
  caldera = {
    hostname = "caldera";
    stateVersion = "25.11";

    user = {
      login = "elyria";
      name = "Elyria";
      git = {
        name = "SylvaraTheDev";
        email = "wing@elyria.dev";
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

    disk = "/dev/disk/by-id/REPLACE-WITH-NVME-ID";
    swapSize = "8G";

    printer = {
      serial = "/dev/ttyUSB0";
      configDir = "/var/lib/klipper";
    };
  };
}
