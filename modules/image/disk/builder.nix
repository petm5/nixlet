{ config, lib, pkgs, ... }: let

  inherit (pkgs.stdenv.hostPlatform) efiArch;

  initialPartitions = {
    "10-usr" = {
      storePaths = [ config.system.build.toplevel ];
      stripNixStorePrefix = true;
      repartConfig = {
        Type = "usr";
        Minimize = "best";
        Format = "erofs";
        Verity = "data";
        VerityMatchKey = "usr";
        SplitName = "usr";
      };
    };
    "20-usr-verity" = {
      repartConfig = {
        Type = "usr-verity";
        Minimize = "best";
        Verity = "hash";
        VerityMatchKey = "usr";
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
          name = "usr-${config.system.image.id}";
          split = true;
          mkfsOptions = lib.mkIf config.image.compress {
            erofs = [ "-zlz4hc,level=12" "-Efragments,dedupe,ztailpacking" ];
          };
          partitions = initialPartitions;
        };
      })
    ];
  };

  usrPart = "${verityRepart.config.system.build.image}/${verityRepart.config.image.repart.imageFileBasename}.usr.raw";
  verityPart = "${verityRepart.config.system.build.image}/${verityRepart.config.image.repart.imageFileBasename}.verity.raw";

  verityImgAttrs = builtins.fromJSON (builtins.readFile "${verityRepart.config.system.build.image}/repart-output.json");
  usrAttrs = builtins.elemAt verityImgAttrs 0;
  verityAttrs = builtins.elemAt verityImgAttrs 1;

  usrUuid = usrAttrs.uuid;
  verityUuid = verityAttrs.uuid;
  verityUsrHash = usrAttrs.roothash;

  finalPartitions = {
    "10-esp" = {
      contents = {
        "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
          "${pkgs.systemdUkify}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
        "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
          "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
        "/EFI/loader/keys/nixlet".source = ../../../keys;
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
    "20-usr-verity-a" = {
      repartConfig = {
        Type = "usr-verity";
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
    "22-usr-a" = {
      repartConfig = {
        Type = "usr";
        Label = "usr-${config.system.image.version}";
        CopyBlocks = "${usrPart}";
        SplitName = "-";
        UUID = "${usrUuid}";
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

    inherit verityUsrHash;

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
        name = "${config.system.image.id}_${config.system.image.version}_${usrUuid}.usr";
        path = "${verityRepart.config.system.build.image}/${verityRepart.config.image.repart.imageFileBasename}.usr.raw";
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
