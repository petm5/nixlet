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

}
