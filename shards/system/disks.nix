{ config, ... }:

let
  cfg = config.caldera;

  btrfsMountOpts = [
    "compress=zstd:1"
    "noatime"
    "ssd"
    "discard=async"
    "space_cache=v2"
  ];
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = cfg.disk;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "defaults"
                "umask=0077"
              ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = btrfsMountOpts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsMountOpts;
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = btrfsMountOpts;
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = btrfsMountOpts;
                };
                "@swap" = {
                  mountpoint = "/swap";
                  mountOptions = [
                    "noatime"
                    "ssd"
                  ];
                  swap = {
                    swapfile.size = cfg.swapSize;
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
