{
  config,
  lib,
  pkgs,
  ...
}:

{
  # === Intel + NVIDIA Hybrid (Optimus) ===
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = lib.mkIf (config.caldera.gpu == "nvidia") (
      with pkgs;
      [
        nvidia-vaapi-driver
        libva
        libva-utils
        vulkan-loader
        intel-media-driver
      ]
    );
  };

  # NVIDIA driver
  services.xserver.videoDrivers = lib.mkIf (config.caldera.gpu == "nvidia") [ "nvidia" ];
  hardware.nvidia = lib.mkIf (config.caldera.gpu == "nvidia") {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;

    # NVIDIA Prime — hybrid Intel + Nvidia laptop
    # Verify bus IDs: lspci | grep -E 'VGA|3D'
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # NVIDIA kernel params
  boot.kernelParams = lib.mkIf (config.caldera.gpu == "nvidia") [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];

  # NVIDIA + Wayland environment variables
  environment.variables = lib.mkIf (config.caldera.gpu == "nvidia") {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    GBM_BACKEND = "nvidia-drm";
    NVD_BACKEND = "direct";
  };
}
