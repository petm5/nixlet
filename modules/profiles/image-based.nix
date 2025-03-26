{ lib, ... }: {

  # System cannot be rebuilt
  nix.enable = false;
  system.switch.enable = false;

  nixpkgs.flake.setNixPath = false;
  nixpkgs.flake.setFlakeRegistry = false;

  # Try to avoid interpreters
  networking.useNetworkd = true;
  systemd.network.wait-online.enable = lib.mkDefault false;
  boot.initrd.systemd.enable = true;

  # Use a simple bootloader
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;

  # The system does not need "human" users
  services.userborn.enable = false;
  systemd.sysusers.enable = true;

  systemd.services."systemd-oomd".unitConfig.After = "systemd-sysusers.service";

}
