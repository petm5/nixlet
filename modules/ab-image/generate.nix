{ config, lib, pkgs, modulesPath, ... }:
let

  cfg = config.ab-image;

  arch =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then "x86-64"
    else if pkgs.stdenv.hostPlatform.system == "armv7l-linux" then "arm"
    else throw "Unsupported architecture";

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
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
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

  imports = [
    (modulesPath + "/image/repart.nix")
  ];

  config = lib.mkMerge ([{
    image.repart.partitions = {
      "20-esp" = {
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
          Label = "esp";
          SizeMinBytes = "96M";
        };
      };
      "30-root" = {
        storePaths = [ config.system.build.toplevel ];
        repartConfig = {
          Type = "root-${arch}";
          Label = "${cfg.version}";
          Format = "squashfs";
          Minimize = "guess";
          SplitName = "root";
          SizeMaxBytes = "512M";
        };
        stripNixStorePrefix = true;
      };
    };

    image.repart.split = true;
    image.repart.mkfsOptions = {
      squashfs = [ "-comp zstd" ];
    };

    system.build.ab-image = pkgs.callPackage ./release.nix {
      inherit (cfg) version;
      rootfsPath = config.system.build.image + "/${config.image.repart.imageFileBasename}.root.raw";
      imagePath = config.system.build.image + "/${config.image.repart.imageFileBasename}.raw";
      ukiPath = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
    };

    boot.initrd.systemd.additionalUpstreamUnits = [ "initrd-usr-fs.target" ];

    fileSystems = {
      # systemd expects to find the root FS here
      "/usr" = {
        fsType = "squashfs";
        device = "/dev/disk/by-partlabel/${cfg.version}";
      };
      "/nix/store" = {
        fsType = "none";
        device = "/usr";
        options = [ "bind" ];
      };
      "/boot" = {
        fsType = "vfat";
        device = "/dev/disk/by-partlabel/esp";
        neededForBoot = true;
      };
      "/" = {
        fsType = "btrfs";
        device = "/dev/disk/by-partlabel/state";
        options = [ "noexec" ];
      };
    };

    boot.initrd.systemd.repart.enable = true;
    systemd.repart.partitions = {
      "10-root-a" = {
        Type = "root";
        SizeMinBytes = "512M";
        SizeMaxBytes = "512M";
      };

      "20-root-b" = {
        Type = "root";
        Label = "_empty";
        SizeMinBytes = "512M";
        SizeMaxBytes = "512M";
      };

      "30-data" = {
        Type = "linux-generic";
        Label = "state";
        Format = "btrfs";
        MakeDirectories = "/home /etc /var";
        Subvolumes = "/home";
        FactoryReset = true;
        Encrypt = lib.optionalString cfg.luks.enable "key-file";
      };
    };
    boot.initrd.systemd.services.systemd-repart = {
      serviceConfig = {
        Environment = [
          "PATH=${pkgs.btrfs-progs}/bin" # Help systemd-repart to find btrfs-progs
        ];
        ExecStart = [
          " "
          (lib.strings.concatStrings [ ''${config.boot.initrd.systemd.package}/bin/systemd-repart \
            --definitions=/etc/repart.d \
            --dry-run no \
          '' (lib.optionalString cfg.luks.enable " --key-file=/etc/default-luks-key") ])
        ];
      };
      after = lib.mkForce [];
    };
    boot.initrd.systemd.storePaths = [
      "${pkgs.btrfs-progs}/bin/btrfs"
      "${pkgs.btrfs-progs}/bin/mkfs.btrfs"
    ];
  }
  (lib.mkIf cfg.luks.enable {
    boot.initrd.systemd.contents."/etc/default-luks-key".text = cfg.luks.defaultKey;
    boot.initrd.luks.devices."state".device = "/dev/disk/by-partlabel/state";
    fileSystems."/".device = lib.mkForce "/dev/mapper/state";
  })
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
          MatchPattern = "${cfg.name}_@v.rootfs";
        };
        Target = {
          Type = "partition";
          MatchPartitionType = "root";
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
