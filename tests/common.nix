{ lib, pkgs, ... }:

let

  qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix") { inherit (pkgs) lib stdenv; };

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

  makeImageTest = { name, image, script, httpRoot ? null, sshAuthorizedKey ? null }:
  pkgs.testers.runNixOSTest ( { config, lib, ... }: {
    inherit name;
    nodes.machine = { config, lib, ... }:
      let
        cfg = config.virtualisation;
        qemu = cfg.qemu.package;
        qemu-img = lib.getExe' qemu "qemu-img";
        mkDiskImage = pkgs.writeShellScript "mutable-disk.img" ''
          NIX_DISK_IMAGE=$(readlink -f "./${config.system.name}.qcow2")

          ${qemu-img} create \
            -f qcow2 \
            -b ${image} \
            -F raw \
            "$NIX_DISK_IMAGE" \
            "${toString cfg.diskSize}M" \
            >&2

          echo "$NIX_DISK_IMAGE"
        '';
      in {
        nix.enable = false;

        virtualisation.cores = 1;
        virtualisation.memorySize = 512;
        virtualisation.diskSize = 4096;

        virtualisation.useBootLoader = true;
        virtualisation.useEFIBoot = true;

        virtualisation.tpm.enable = true;

        virtualisation.credentials = lib.mkIf (sshAuthorizedKey != null) {
          "ssh.authorized_keys.root".text = sshAuthorizedKey;
        };

        virtualisation.useDefaultFilesystems = false;
        virtualisation.efi.keepVariables = false;
        boot.initrd.enable = false;
        system.build.initialRamdisk = "";
        virtualisation.diskImage = null;

        virtualisation.qemu.networkingOptions = lib.mkIf (httpRoot != null) (lib.mkOverride 10 [
          "-net nic,netdev=user.0,model=virtio"
          "-netdev" "'user,id=user.0,guestfwd=tcp:10.0.2.1:80-cmd:${pkgs.micro-httpd}/bin/micro_httpd ${httpRoot}'"
        ]);

        virtualisation.qemu.drives = [
          {
            name = "disk";
            file = "$(${mkDiskImage})";
          }
        ];
      };
    testScript = script;
  } );

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
