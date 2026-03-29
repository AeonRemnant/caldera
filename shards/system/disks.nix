{ ... }:

let
  btrfsMountOpts = [
    "compress=zstd:1"
    "noatime"
    "ssd"
    "discard=async"
    "space_cache=v2"
  ];
in
{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/caldera";
      fsType = "btrfs";
      options = [ "subvol=@root" ] ++ btrfsMountOpts;
    };
    "/nix" = {
      device = "/dev/disk/by-label/caldera";
      fsType = "btrfs";
      options = [ "subvol=@nix" ] ++ btrfsMountOpts;
    };
    "/home" = {
      device = "/dev/disk/by-label/caldera";
      fsType = "btrfs";
      options = [ "subvol=@home" ] ++ btrfsMountOpts;
    };
    "/var/log" = {
      device = "/dev/disk/by-label/caldera";
      fsType = "btrfs";
      options = [ "subvol=@log" ] ++ btrfsMountOpts;
    };
    "/swap" = {
      device = "/dev/disk/by-label/caldera";
      fsType = "btrfs";
      options = [
        "subvol=@swap"
        "noatime"
        "ssd"
      ];
    };
    "/config" = {
      device = "/dev/disk/by-label/caldera";
      fsType = "btrfs";
      options = [ "subvol=@flake" ] ++ btrfsMountOpts;
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [
        "defaults"
        "umask=0077"
      ];
    };
  };

  swapDevices = [
    { device = "/swap/swapfile"; }
  ];
}
