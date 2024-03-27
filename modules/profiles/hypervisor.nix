{ pkgs, ... }: let
  qemu = pkgs.qemu_test;
in {

  imports = [ ./server.nix ];

  virtualisation.libvirtd = {
    enable = true;
    package = pkgs.libvirt.override {
      enableZfs = false;
    };
    qemu.package = qemu;
    qemu.ovmf.enable = false;
  };

  boot.enableContainers = true;

  # Support disk arrays
  boot.initrd.services.lvm.enable = true;
  boot.swraid.enable = true;
  boot.initrd.kernelModules = [ "raid0" "raid1" ];

}
