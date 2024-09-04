{ pkgs, self }:

with import (pkgs.path + "/nixos/lib/testing-python.nix") { inherit pkgs; inherit (pkgs.hostPlatform) system; };

let
  lib = pkgs.lib;
  nixos-lib = import (pkgs.path + "/nixos/lib") {};
  qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix") { inherit lib pkgs; };

  makeSystem = extraConfig:
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
        system.image.id = "test";
        system.image.updates.url = "http://10.0.2.1/";
      }
      {
        boot.kernelParams = [ "console=ttyS0,115200n8" "systemd.journald.forward_to_console=1" ];
        image.repart.mkfsOptions.squashfs = lib.mkForce [ "-comp zstd" "-Xcompression-level 6" "-b 256K" ];
        boot.initrd.compressor = lib.mkForce "zstd";
        boot.initrd.compressorArgs = lib.mkForce [ "-8" ];
      }
      (pkgs.path + "/nixos/modules/testing/test-instrumentation.nix")
      self.nixosModules.server
      self.nixosModules.image
      extraConfig
    ];
  };

  testSystem = makeSystem {
    system.image.version = "1";
  };

  updateSystem = makeSystem {
    system.image.version = "2";
  };

  systemd = testSystem.config.systemd.package;

  diskImage = "${testSystem.config.system.build.image}/${testSystem.config.image.repart.imageFile}";
  updateImage = "${updateSystem.config.system.build.image}/${updateSystem.config.image.repart.imageFile}";

  mutableImage = "/tmp/linked-image.qcow2";
  tpmFolder = "/tmp/emulated_tpm";

  httpRoot = updateSystem.config.system.build.updatePackage;

  lighttpdConfig = pkgs.writeText "lighttpd.conf" ''
    server.document-root = "${httpRoot}"
    server.port = 8989
  '';

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
      "-netdev" "user,id=net0,guestfwd=tcp:10.0.2.1:80-tcp:127.0.0.1:8989"
      "-device" "virtio-net-pci,netdev=net0"
    ];
    flagsStr = lib.concatStringsSep " " flags;
  in "${qemu} ${flagsStr}";
in makeTest {
  name = "system-update";
  nodes = { };
  testScript = ''
    import os
    import subprocess

    subprocess.check_call(["cat", "${httpRoot}/SHA256SUMS"])

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

    def start_tpm():
      subprocess.Popen(
          [
              "${pkgs.swtpm}/bin/swtpm",
              "socket",
              "--tpmstate", "dir=${tpmFolder}/swtpm",
              "--ctrl", "type=unixio,path=${tpmFolder}/swtpm-sock",
              "--tpm2"
          ]
      )

    subprocess.Popen(
        [
            "${pkgs.lighttpd}/bin/lighttpd",
            "-f" "${lighttpdConfig}",
            "-D"
        ]
    )

    machine = create_machine("${startCommand}")

    start_tpm()
    machine.start()

    try:
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("network.target")

      machine.succeed("${systemd}/lib/systemd/systemd-sysupdate check-new")
      machine.succeed("${systemd}/lib/systemd/systemd-sysupdate update")

      machine.shutdown()

      start_tpm()
      machine.start()

      machine.wait_for_unit("multi-user.target")

      machine.succeed('. /etc/os-release; [ "$IMAGE_VERSION" == "${updateSystem.config.system.image.version}" ]')
    finally:
      machine.shutdown()
  '';
}
