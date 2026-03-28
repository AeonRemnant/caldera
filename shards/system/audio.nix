_:

{
  # Disable power saving on Intel HDA (prevents audio crackling)
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=0
  '';

  # Realtime scheduling for PipeWire
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
