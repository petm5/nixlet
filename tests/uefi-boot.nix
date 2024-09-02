# Extremely basic test for uefi boot and shell functionality
{ pkgs, self }:

with import (pkgs.path + "/nixos/lib/testing-python.nix") { inherit pkgs; inherit (pkgs.hostPlatform) system; };

let
  lib = pkgs.lib;
  nixos-lib = import (pkgs.path + "/nixos/lib") {};
  qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix") { inherit lib pkgs; };

  image =
    ((import (pkgs.path + "/nixos/lib/eval-config.nix")) {
      inherit pkgs lib;
      system = null;
      modules = [
        {
          nixpkgs.hostPlatform = pkgs.hostPlatform;
        }
        {
          users.allowNoPasswordLogin = true;
          system.stateVersion = lib.versions.majorMinor lib.version;
        }
        {
          boot.initrd.availableKernelModules = [ "virtio_net" "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_scsi" "virtio_balloon" "virtio_console" ];
        }
        (pkgs.path + "/nixos/modules/testing/test-instrumentation.nix")
        self.nixosModules.server
        self.nixosModules.image
      ];
    }).config.system.build.image;

  startCommand = let
    qemu = qemu-common.qemuBinary pkgs.qemu_test;
    flags = [
      "-m" "512M"
      "-netdev" "user,id=net0"
      "-device" "virtio-net-pci,netdev=net0"
      "-drive" "if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}"
      "-drive" "if=pflash,format=raw,unit=1,readonly=on,file=${pkgs.OVMF.variables}"
      "-kernel" "${efiBundle}/EFI/Linux/*.efi"
    ];
    flagsStr = lib.concatStringsSep " " flags;
  in "${qemu} ${flagsStr}";
in makeTest {
  name = "boot-uefi-bundle";
  nodes = {};
  testScript = ''
    machine = create_machine("${startCommand}")
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("echo OK")
    machine.shutdown()
  '';
}
