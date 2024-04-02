{ config, lib, pkgs, modulesPath, utils, ... }:
let

  cfg = config.ab-image;

  efiArch = pkgs.stdenv.hostPlatform.efiArch;

in

{

  options.ab-image = {
    name = lib.mkOption {
      default = config.system.image.id;
      type = lib.types.str;
      readOnly = true;
    };
    version = lib.mkOption {
      default = "${cfg.name}_${config.system.image.version}";
      type = lib.types.str;
      readOnly = true;
    };

    luks = {
      defaultKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = lib.mdDoc ''
          Initial passphrase used for disk encryption.
        '';
      };
    };

    updates = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      url = lib.mkOption {
        type = lib.types.str;
        description = lib.mdDoc ''
          URL used by systemd-sysupdate to fetch OTA updates
        '';
      };
    };
  };

  imports = [(modulesPath + "/image/repart.nix")];

  config = lib.mkMerge ([{
    system.build.erofs = pkgs.callPackage ./erofs.nix {
      storeContents = [ config.system.build.toplevel ];
      label = cfg.version;
    };

    image.repart.partitions = {
      "10-esp" = {
        contents = lib.mkMerge [
          {
            "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
              "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

            "/EFI/Linux/${cfg.version}.efi".source =
              "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          }
          (lib.mkIf config.hardware.deviceTree.enable {
          "/${config.hardware.deviceTree.name}".source =
            "${config.hardware.deviceTree.dtbSource}/${config.hardware.deviceTree.name}";
          })
        ];
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = "96M";
          Label = "esp";
        };
      };
      "20-usr" = {
        repartConfig = {
          Type = "usr";
          SizeMaxBytes = "512M";
          Label = cfg.version;
          CopyBlocks = "${config.system.build.erofs}";
        };
        stripNixStorePrefix = true;
      };
    };

    system.build.ab-image = pkgs.callPackage ./ab-image-release.nix {
      inherit (cfg) version;
      usrPath = "${config.system.build.erofs}";
      imagePath = config.system.build.image + "/${config.image.repart.imageFileBasename}.raw";
      ukiPath = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
    };

    boot.initrd.systemd.additionalUpstreamUnits = [ "initrd-usr-fs.target" ];

    fileSystems = lib.mkOverride 50 {
      "/" = {
        fsType = "btrfs";
        device = "/dev/mapper/state";
        encrypted = {
          enable = true;
          blkDev = "/dev/disk/by-partlabel/state";
          label = "state";
        };
      };
      "/usr" = {
        fsType = "erofs";
        label = cfg.version;
      };
      "/nix/store" = {
        fsType = "none";
        device = "/usr";
        options = [ "bind" ];
        neededForBoot = true;
      };
      "/boot" = {
        fsType = "vfat";
        device = "/dev/disk/by-partlabel/esp";
        neededForBoot = true;
      };
    };

    boot.initrd.systemd.repart.enable = true;
    systemd.repart.partitions = {
      "10-root-a" = {
        Type = "usr";
        SizeMinBytes = "512M";
        SizeMaxBytes = "512M";
      };

      "20-root-b" = {
        Type = "usr";
        Label = "_empty";
        SizeMinBytes = "512M";
        SizeMaxBytes = "512M";
      };

      "30-state" = {
        Type = "linux-generic";
        Label = "state";
        Format = "btrfs";
        MakeDirectories = "/home /etc /var";
        Subvolumes = "/home";
        FactoryReset = true;
        Encrypt = "key-file";
      };
    };
    boot.initrd.systemd.services.systemd-repart = {
      serviceConfig = {
        Environment = [
          "PATH=${pkgs.btrfs-progs}/bin" # Help systemd-repart to find btrfs-progs
        ];
        ExecStart = [
          " "
          ''${config.boot.initrd.systemd.package}/bin/systemd-repart \
            --definitions=/etc/repart.d \
            --dry-run no \
            --key-file=/etc/default-luks-key
          ''
        ];
      };
      after = lib.mkForce [];
    };
    boot.initrd.systemd.storePaths = [
      "${pkgs.btrfs-progs}/bin/btrfs"
      "${pkgs.btrfs-progs}/bin/mkfs.btrfs"
    ];
    boot.initrd.systemd.contents."/etc/default-luks-key".text = cfg.luks.defaultKey;
  }
  (lib.mkIf cfg.updates.enable {
    systemd.sysupdate.enable = true;
    systemd.sysupdate.reboot.enable = lib.mkDefault true;
    systemd.sysupdate.transfers = {
      "10-rootfs" = {
        Transfer = {
          Verify = "no";
        };
        Source = {
          Type = "url-file";
          Path = "${cfg.updates.url}";
          MatchPattern = "${cfg.name}_@v.usr";
        };
        Target = {
          Type = "partition";
          MatchPartitionType = "usr";
          Path = "auto";
          MatchPattern = "${cfg.name}_@v";
        };
      };
      "20-uki" = {
        Transfer = {
          Verify = "no";
        };
        Source = {
          Type = "url-file";
          Path = "${cfg.updates.url}";
          MatchPattern = "${cfg.name}_@v.efi";
        };
        Target = {
          Type = "regular-file";
          Path = "/EFI/Linux";
          PathRelativeTo = "esp";
          # Boot counting is not supported yet, see https://github.com/NixOS/nixpkgs/pull/273062
          MatchPattern = ''
            ${cfg.name}_@v.efi
          '';
          Mode = "0444";
          TriesLeft = 3;
          TriesDone = 0;
          InstancesMax = 2;
        };
      };
    };
  })]);

}
