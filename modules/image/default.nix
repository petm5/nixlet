{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    ./updater.nix
    ./ssh.nix
    ./repart-verity-store.nix
    ./filesystems.nix
  ];

  boot.initrd.systemd.enable = true;

  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = [ "-6" ];

  boot.loader.grub.enable = false;

  boot.initrd.supportedFilesystems = {
    btrfs = true;
  };

  system.etc.overlay.mutable = true;

  services.userborn.enable = false;
  systemd.sysusers.enable = true;

}
