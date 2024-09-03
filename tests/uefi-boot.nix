# Extremely basic test for uefi boot and shell functionality
{ pkgs, self }:

with import (pkgs.path + "/nixos/lib/testing-python.nix") { inherit pkgs; inherit (pkgs.hostPlatform) system; };

let
  lib = pkgs.lib;
  nixos-lib = import (pkgs.path + "/nixos/lib") {};
  qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix") { inherit lib pkgs; };

  testSystem =
    (import (pkgs.path + "/nixos/lib/eval-config.nix")) {
      inherit pkgs lib;
      system = null;
      modules = [
        {
          nixpkgs.hostPlatform = pkgs.hostPlatform;
        }
        {
          users.allowNoPasswordLogin = true;
          system.stateVersion = lib.versions.majorMinor lib.version;
          system.image.id = "nixos-image";
          system.image.version = "1";
        }
        {
          boot.kernelParams = [ "console=ttyS0,115200n8" "systemd.journald.forward_to_console=1" ];
          image.repart.mkfsOptions.squashfs = lib.mkForce [ "-comp zstd" "-Xcompression-level 2" "-b 64K" ];
          boot.initrd.compressor = lib.mkForce "zstd";
          boot.initrd.compressorArgs = lib.mkForce [ "-2" ];
        }
        (pkgs.path + "/nixos/modules/testing/test-instrumentation.nix")
        self.nixosModules.server
        self.nixosModules.image
      ];
    };

  diskImage = "${testSystem.config.system.build.image}/${testSystem.config.image.repart.imageFile}";
  mutableImage = "/tmp/linked-image.qcow2";
  tpmFolder = "/tmp/emulated_tpm";

  startCommand = let
    qemu = qemu-common.qemuBinary pkgs.qemu_test;
    flags = [
      "-m" "512M"
      "-drive" "if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}"
      "-drive" "if=pflash,format=raw,unit=1,readonly=on,file=${pkgs.OVMF.variables}"
      "-drive" "if=virtio,file=${mutableImage}"
      "-chardev" "socket,id=chrtpm,path=${tpmFolder}/swtpm-sock"
      "-tpmdev" "emulator,id=tpm0,chardev=chrtpm"
      "-device" "tpm-tis,tpmdev=tpm0"
    ];
    flagsStr = lib.concatStringsSep " " flags;
  in "${qemu} ${flagsStr}";
in makeTest {
  name = "boot-uefi-bundle";
  nodes = { };
  testScript = ''
    import os
    import subprocess

    subprocess.check_call(
        [
            "qemu-img",
            "create",
            "-f",
            "qcow2",
            "-F",
            "raw",
            "-b",
            "${diskImage}",
            "${mutableImage}",
        ]
    )
    subprocess.check_call(["qemu-img", "resize", "${mutableImage}", "4G"])

    os.mkdir("${tpmFolder}")
    os.mkdir("${tpmFolder}/swtpm")

    subprocess.Popen(
        [
            "${pkgs.swtpm}/bin/swtpm",
            "socket",
            "--tpmstate", "dir=${tpmFolder}/swtpm",
            "--ctrl", "type=unixio,path=${tpmFolder}/swtpm-sock",
            "--tpm2"
        ]
    )

    machine = create_machine("${startCommand}")
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("echo OK")
    machine.shutdown()
  '';
}
