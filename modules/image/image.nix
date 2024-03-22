{ config, lib, pkgs, modulesPath, ... }:
let

  cfg = config.image;

  imageName = "nixos_${config.system.image.id}";
  versionString = "${imageName}_${config.system.image.version}";

  arch =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then "x86-64"
    else if pkgs.stdenv.hostPlatform.system == "armv7l-linux" then "arm"
    else throw "Unsupported architecture";

  efiArch = pkgs.stdenv.hostPlatform.efiArch;

in

{

  options = {

    image = {
    
      dataLabel = lib.mkOption {
        default = "data";
        type = lib.types.str;
        description = lib.mdDoc ''
          Label used for the persistent data partition.
        '';
      };

      luks = {
      
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };

        defaultKey = lib.mkOption {
          type = lib.types.str;
          default = "changeme";
          description = lib.mdDoc ''
            Initial passphrase used for disk encryption.
          '';
        };

      };

    };

    release = lib.mkOption {
      type = lib.types.str;
      description = lib.mdDoc ''
        Incremental version number for releases.
      '';
    };

    updateUrl = lib.mkOption {
      type = lib.types.str;
      description = lib.mdDoc ''
        URL used by systemd-sysupdate to fetch OTA updates
      '';
    };

  };

  imports = [
    (modulesPath + "/image/repart.nix")
    (modulesPath + "/profiles/image-based-appliance.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  config = {

    system.etc.overlay.mutable = true;

    users.mutableUsers = lib.mkForce true;
    users.allowNoPasswordLogin = true;

    environment.etc."machine-id".text = " ";

    image.repart = {
      split = true;
      partitions = {
        "20-esp" = {
          contents = lib.mkMerge [
            {
              "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
                "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

              "/EFI/Linux/${versionString}.efi".source =
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
            Label = "${versionString}";
            Format = "squashfs";
            Minimize = "guess";
            SplitName = "root";
            SizeMaxBytes = "512M";
          };
          stripNixStorePrefix = true;
        };
      };
      mkfsOptions = {
        squashfs = [ "-comp zstd" ];
      };
    };

    system.build.image-release = pkgs.callPackage ./release.nix {
      version = versionString;
      rootfsPath = config.system.build.image + "/${config.image.repart.imageFileBasename}.root.raw";
      imagePath = config.system.build.image + "/${config.image.repart.imageFileBasename}.raw";
      ukiPath = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
    };

    boot.initrd.systemd = {
      enable = true;
      storePaths = [
        "${pkgs.btrfs-progs}/bin/btrfs"
        "${pkgs.btrfs-progs}/bin/mkfs.btrfs"
      ];
    };

    boot.loader.grub.enable = false;

    boot.initrd.luks.devices = lib.mkIf cfg.luks.enable {
      "data" = {
        device = "/dev/disk/by-partlabel/${cfg.dataLabel}";
      };
    };

    fileSystems = let
      dataDevice = if cfg.luks.enable then "/dev/mapper/data" else "/dev/disk/by-partlabel/${cfg.dataLabel}";
    in {
      "/" = {
        fsType = "btrfs";
        device = dataDevice;
        options = [ "subvol=@" ];
      };

      # systemd expects to find the root FS here
      "/usr" = {
        fsType = "squashfs";
        device = "/dev/disk/by-partlabel/${versionString}";
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

      "/etc" = {
        device = dataDevice;
        options = [ "subvol=@etc" ];
      };

      "/var" = {
        device = dataDevice;
        options = [ "subvol=@var" ];
      };

      "/home" = {
        device = dataDevice;
        options = [ "subvol=@home" ];
        neededForBoot = true;
      };
    };

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
        Label = "${cfg.dataLabel}";
        Format = "btrfs";
        MakeDirectories = "/@ /@home /@etc /@var";
        Subvolumes = "/@ /@home /@etc /@var";
        FactoryReset = true;
        Encrypt = lib.optionalString cfg.luks.enable "key-file";
      };
    };

    boot.initrd.systemd.contents = lib.mkMerge ([(lib.mkIf cfg.luks.enable {
      "/etc/default-luks-key" =  {
        text = cfg.luks.defaultKey;
      };
    })]);

    boot.initrd.systemd.repart.enable = true;

    boot.initrd.systemd.additionalUpstreamUnits = [ "initrd-usr-fs.target" ];

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

    systemd.sysupdate.enable = true;
    systemd.sysupdate.reboot.enable = true;
    systemd.sysupdate.transfers = {
      "10-rootfs" = {
        Transfer = {
          Verify = "no";
        };
        Source = {
          Type = "url-file";
          Path = "${config.updateUrl}";
          MatchPattern = "${imageName}_@v.rootfs";
        };
        Target = {
          Type = "partition";
          MatchPartitionType = "root";
          Path = "auto";
          MatchPattern = "${imageName}_@v";
        };
      };

      "20-uki" = {
        Transfer = {
          Verify = "no";
        };
        Source = {
          Type = "url-file";
          Path = "${config.updateUrl}";
          MatchPattern = "${imageName}_@v.efi";
        };
        Target = {
          Type = "regular-file";
          Path = "/EFI/Linux";
          PathRelativeTo = "esp";
          # Boot counting is not supported yet, see https://github.com/NixOS/nixpkgs/pull/273062
          MatchPattern = ''
            ${imageName}_@v.efi
          '';
          Mode = "0444";
          TriesLeft = 3;
          TriesDone = 0;
          InstancesMax = 2;
        };
      };
    };

  };

}
