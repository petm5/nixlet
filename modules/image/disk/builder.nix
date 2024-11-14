{ config, lib, pkgs, ... }: let

  inherit (pkgs.stdenv.hostPlatform) efiArch;

  initialPartitions = {
    "10-root" = {
      storePaths = [ config.system.build.toplevel ];
      repartConfig = {
        Type = "root";
        Minimize = "best";
        Format = "erofs";
        MakeDirectories = "/home /root /etc /dev /sys /bin /var /proc /run /usr /srv /tmp /mnt /lib /efi";
        Verity = "data";
        VerityMatchKey = "root";
        SplitName = "root";
      };
    };
    "20-root-verity" = {
      repartConfig = {
        Type = "root-verity";
        Minimize = "best";
        Verity = "hash";
        VerityMatchKey = "root";
        SplitName = "verity";
      };
    };
  };

  # TODO: We don't need a combined image here - add dry-run flag to repart invocation
  verityRepart = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    inherit lib pkgs;
    system = null;
    modules = [
      ({ modulesPath, ... }: {
        imports = [
          (modulesPath + "/image/repart.nix")
        ];
        image.repart = {
          name = "rootfs-${config.system.image.id}";
          split = true;
          mkfsOptions = lib.mkIf config.image.compress {
            erofs = [ "-zlz4hc,level=12" "-Efragments,dedupe,ztailpacking" ];
          };
          partitions = initialPartitions;
        };
      })
    ];
  };

  rootPart = "${verityRepart.config.system.build.image}/${verityRepart.config.image.repart.imageFileBasename}.root.raw";
  verityPart = "${verityRepart.config.system.build.image}/${verityRepart.config.image.repart.imageFileBasename}.verity.raw";

  verityImgAttrs = builtins.fromJSON (builtins.readFile "${verityRepart.config.system.build.image}/repart-output.json");
  rootAttrs = builtins.elemAt verityImgAttrs 0;
  verityAttrs = builtins.elemAt verityImgAttrs 1;

  rootUuid = rootAttrs.uuid;
  verityUuid = verityAttrs.uuid;
  verityRootHash = rootAttrs.roothash;

  finalPartitions = {
    "10-esp" = {
      contents = {
        "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
          "${pkgs.systemdUkify}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
        "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
          "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
        "/default-ssh-authorized-keys.txt" = lib.mkIf config.system.image.sshKeys.enable {
          source = pkgs.writeText "ssh-keys" (lib.concatStringsSep "\n" config.system.image.sshKeys.keys);
        };
      };
      repartConfig = {
        Type = "esp";
        Format = "vfat";
        SizeMinBytes = "96M";
        SizeMaxBytes = "96M";
        SplitName = "-";
      };
    };
    "20-root-verity-a" = {
      repartConfig = {
        Type = "root-verity";
        Label = "verity-${config.system.image.version}";
        CopyBlocks = "${verityPart}";
        SplitName = "-";
        SizeMinBytes = "64M";
        SizeMaxBytes = "64M";
        UUID = "${verityUuid}";
        ReadOnly = 1;
      };
    };
    # TODO: Add signature partition for systemd-nspawn
    "22-root-a" = {
      repartConfig = {
        Type = "root";
        Label = "root-${config.system.image.version}";
        CopyBlocks = "${rootPart}";
        SplitName = "-";
        UUID = "${rootUuid}";
        ReadOnly = 1;
      };
    };
  };

  finalRepart = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    inherit lib pkgs;
    system = null;
    modules = [
      ({ modulesPath, ... }: {
        imports = [
          (modulesPath + "/image/repart.nix")
        ];
        image.repart = {
          name = "image-${config.system.image.id}";
          partitions = finalPartitions;
        };
      })
    ];
  };

in {

  options.image.compress = lib.mkEnableOption "image compression" // {
    default = true;
  };

  config.system.build = {

    inherit verityRootHash;

    image = (pkgs.linkFarm "image-release" [
      {
        name = "${config.system.image.id}_${config.system.image.version}.efi";
        path = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
      }
      {
        name = "${config.system.image.id}_${config.system.image.version}_${verityUuid}.verity";
        path = "${verityRepart.config.system.build.image}/${verityRepart.config.image.repart.imageFileBasename}.verity.raw";
      }
      {
        name = "${config.system.image.id}_${config.system.image.version}_${rootUuid}.root";
        path = "${verityRepart.config.system.build.image}/${verityRepart.config.image.repart.imageFileBasename}.root.raw";
      }
      {
        name = "${config.system.image.id}_${config.system.image.version}.img";
        path = "${finalRepart.config.system.build.image}/${finalRepart.config.image.repart.imageFileBasename}.raw";
      }
    ]) // {
      imageFile = "${config.system.image.id}_${config.system.image.version}.img";
    };

  };

}
