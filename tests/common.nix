{ self, lib, pkgs, ... }:

with import (pkgs.path + "/nixos/lib/testing-python.nix") { inherit pkgs; inherit (pkgs.hostPlatform) system; };

let

  nixos-lib = import (pkgs.path + "/nixos/lib") {};
  qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix") { inherit lib pkgs; };

in rec {

  makeSystem = extraConfig:
  (import (pkgs.path + "/nixos/lib/eval-config.nix")) {
    inherit pkgs lib;
    system = null;
    modules = [
      (pkgs.path + "/nixos/modules/image/repart.nix")
      ../modules/image/repart-image-verity-store-defaults.nix
      ../modules/image/update-package.nix
      ../modules/image/initrd-repart-expand.nix
      ../modules/image/sysupdate-verity-store.nix
      ../modules/profiles/minimal.nix
      ../modules/profiles/image-based.nix
      ../modules/profiles/server.nix
      (pkgs.path + "/nixos/modules/profiles/qemu-guest.nix")
      {
        boot.kernelPackages = pkgs.linuxPackages_latest;
        users.allowNoPasswordLogin = true;
        system.stateVersion = lib.versions.majorMinor lib.version;
        system.image.id = lib.mkDefault "nixos-appliance";
        system.image.version = lib.mkDefault "1";
        networking.hosts."10.0.2.1" = [ "server.test" ];
        boot.kernelParams = [
          "x-systemd.device-timeout=10s"
          "console=ttyS0,115200n8"
        ];
        # Use weak compression
        image.repart.compression.enable = false;
        boot.initrd.compressor = "zstd";
        boot.initrd.compressorArgs = [ "-2" ];
      }
      (pkgs.path + "/nixos/modules/testing/test-instrumentation.nix")
      extraConfig
    ];
  };

  makeImage = extraConfig: let
    system = makeSystem extraConfig;
  in "${system.config.system.build.finalImage}/${system.config.image.fileName}";

  makeUpdatePackage = extraConfig: let
    system = makeSystem extraConfig;
  in "${system.config.system.build.updatePackage}";

  makeImageTest = { name, image, script, httpRoot ? null, sshAuthorizedKey ? null }: let
    qemu = qemu-common.qemuBinary pkgs.qemu_test;
    flags = [
      "-machine" "type=q35,accel=kvm,smm=on"
      "-m" "512M"
      "-drive" "if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}"
      "-drive" "if=pflash,format=raw,unit=1,readonly=on,file=${pkgs.OVMF.variables}"
      "-drive" "if=virtio,file=${mutableImage}"
      "-chardev" "socket,id=chrtpm,path=${tpmFolder}/swtpm-sock"
      "-tpmdev" "emulator,id=tpm0,chardev=chrtpm"
      "-device" "tpm-tis,tpmdev=tpm0"
      "-netdev" ("'user,id=net0" + (lib.optionalString (httpRoot != null) ",guestfwd=tcp:10.0.2.1:80-cmd:${pkgs.micro-httpd}/bin/micro_httpd ${httpRoot}") + "'")
      "-device" "virtio-net-pci,netdev=net0"
    ] ++ (lib.optionals (sshAuthorizedKey != null) [
      "-smbios" ("'type=11,value=io.systemd.credential:ssh.authorized_keys.root=" + sshAuthorizedKey + "'")
    ]);
    flagsStr = lib.concatStringsSep " " flags;
    startCommand = "${qemu} ${flagsStr}";
    mutableImage = "/tmp/linked-image.qcow2";
    tpmFolder = "/tmp/emulated_tpm";
    indentLines = str: lib.concatLines (map (s: "  " + s) (lib.splitString "\n" str));
  in makeTest {
    inherit name;
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
              "${image}",
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

      machine = create_machine("${startCommand}")

      try:
    '' + indentLines script + ''
      finally:
        machine.shutdown()
    '';
  };

  makeInteractiveTest = { image, qemu ? pkgs.qemu_kvm, OVMF ? pkgs.OVMF, runtimeShell ? pkgs.runtimeShell }: let
    qemuCommand = qemu-common.qemuBinary qemu;
    flags = [
      "-m" "512M"
      "-drive" "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF.firmware}"
      "-drive" "if=pflash,format=raw,unit=1,readonly=on,file=${OVMF.variables}"
      "-drive" "if=virtio,file=${mutableImage}"
      "-netdev" "'user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22'"
      "-device" "virtio-net-pci,netdev=net0"
      "-serial" "stdio"
    ];
    flagsStr = lib.concatStringsSep " " flags;
    startCommand = "${qemuCommand} ${flagsStr}";
    mutableImage = "nixlet-disk.qcow2";
    qemuImgCommand = "${qemu}/bin/qemu-img";
    imgFlags = [
      "create"
      "-f" "qcow2"
      "-F" "raw"
      "-b" "${image}"
      "${mutableImage}"
      "2G"
    ];
    imgFlagsStr = lib.concatStringsSep " " imgFlags;
    imgCommand = "${qemuImgCommand} ${imgFlagsStr}";
  in pkgs.writeScript "qemu-interactive-test" ''
    #!${runtimeShell}
    if [ ! -e "${mutableImage}" ]; then
      echo "Creating mutable image at ${mutableImage}"
      ${imgCommand}
    fi
    ${startCommand}
  '';

}
