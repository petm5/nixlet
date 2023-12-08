# Generates a GPT disk image containing a compressed rootfs.

{ config, lib, pkgs, modulesPath, ... }:

with lib;

let

  cfg = config.diskImage;

  version = "${config.osName}_${config.release}";

  kernelPath = "/EFI/Linux/${version}.efi";

  partlabelPath = "/dev/disk/by-partlabel";

  efiArch = pkgs.stdenv.hostPlatform.efiArch;

in

{
  imports = [
    (modulesPath + "/image/repart.nix")
    ./repart-run-early.nix
  ];

  options = {
    diskImage.squashfsCompression = mkOption {
      default = "zstd -Xcompression-level 6";
      type = lib.types.str;
      description = lib.mdDoc ''
        Compression settings to use for the squashfs nix store.
      '';
      example = "zstd -Xcompression-level 6";
    };
    diskImage.homeLabel = mkOption {
      default = "home";
      type = lib.types.str;
      description = lib.mdDoc ''
        Label used for the persistent home partition.
      '';
    };
    osName = lib.mkOption {
      default = "nixos";
      type = lib.types.str;
      description = lib.mdDoc ''
        Name used as a prefix for kernels and root partitions.
      '';
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

  config = {

    boot = {
      initrd = {
        availableKernelModules = [ "squashfs" "overlay" ];
        kernelModules = [ "loop" "overlay" ];

        systemd.enable = lib.mkForce false; # See https://github.com/NixOS/nixpkgs/projects/51 and https://github.com/NixOS/nixpkgs/issues/217173
      };

      supportedFilesystems = [ "btrfs" ];

      loader.grub.enable = false;

      kernelParams = [
        "console=ttyS0"
      ];
    };

    systemd.services."serial-getty@ttyS0".enable = true;

    # Mostly copied from the iso builder
    fileSystems = {
      "/" = {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
        neededForBoot = true;
      };
      
      "/nix/.ro-store" = {
        device = "/dev/root";
        fsType = "squashfs";
        neededForBoot = true;
      };

      "/nix/.rw-store" = {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
        neededForBoot = true;
      };

      "/nix/store" = {
        fsType = "overlay";
        device = "overlay";
        options = [
          "lowerdir=/nix/.ro-store"
          "upperdir=/nix/.rw-store/store"
          "workdir=/nix/.rw-store/work"
        ];
        depends = [
          "/nix/.ro-store"
          "/nix/.rw-store/store"
          "/nix/.rw-store/work"
        ];
      };

      "/boot" = {
        fsType = "vfat";
        device = "${partlabelPath}/esp";
      };

      "/home" = {
        fsType = "btrfs";
        device = "${partlabelPath}/${cfg.homeLabel}";
      };
    };

    system.build.squashfsStore = pkgs.callPackage (modulesPath + "/../lib/make-squashfs.nix") {
      storeContents = config.system.build.toplevel;
      comp = config.diskImage.squashfsCompression;
    };

    system.build.uki = pkgs.callPackage ./make-uki.nix {
      kernelPath = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
      initrdPath = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
      cmdline = "init=${config.system.build.toplevel}/init root=${partlabelPath}/${toString version} ${toString config.boot.kernelParams}";
      osName = "${config.osName}";
    };

    image.repart = {
      name = "${config.osName}";
      partitions = {
        "esp" = {
          contents = {
            "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
              "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

            "${kernelPath}".source =
              "${config.system.build.uki}";
            };
            repartConfig = {
              Type = "esp";
              Format = "vfat";
              Label = "esp";
              SizeMinBytes = "96M";
            };
        };
        "root" = {
          repartConfig = {
            Type = "root";
            Label = "${version}";
            CopyBlocks = "${config.system.build.squashfsStore}";
          };
        };
      };
    };

    system.build.diskImage = config.system.build.image;

    # Expand the image on first boot
    systemd.repart = {
      enable = true;

      partitions = {
        # The existing root partition
        "10-root-a" = {
          Type = "root";
          SizeMinBytes = "512M";
          SizeMaxBytes = "512M";
        };

        # Create a secondary root partition
        "20-root-b" = {
          Type = "root";
          Label = "_empty";
          SizeMinBytes = "512M";
          SizeMaxBytes = "512M";
        };

        # Create a partition for persistent data
        "30-home" = {
          Type = "home";
          Label = "${cfg.homeLabel}";
          Format = "btrfs";
        };
      };
    };

    systemd.sysupdate = {
      enable = true;
      reboot.enable = true;
      transfers = {
        "10-rootfs" = {
          Transfer = {
            Verify = "no";
          };
          Source = {
            Type = "url-file";
            Path = "${config.updateUrl}";
            MatchPattern = "${config.osName}_@v.squashfs";
          };
          Target = {
            Type = "partition";
            MatchPartitionType = "root";
            Path = "auto";
            MatchPattern = "${config.osName}_@v";
          };
        };
        "20-uki" = {
          Transfer = {
            Verify = "no";
          };
          Source = {
            Type = "url-file";
            Path = "${config.updateUrl}";
            MatchPattern = "${config.osName}_@v.efi";
          };
          Target = {
            Type = "regular-file";
            Path = "/EFI/Linux";
            PathRelativeTo = "esp";
            MatchPattern = ''
              ${config.osName}_@v+@l-@d.efi \
              ${config.osName}_@v+@l.efi \
              ${config.osName}_@v.efi
            '';
            Mode = "0444";
            TriesLeft = 3;
            TriesDone = 0;
            InstancesMax = 2;
          };
        };
      };
    };

    system.build.release = pkgs.callPackage ./make-release.nix {
      version = version;
      squashfsPath = config.system.build.squashfsStore;
      ukiPath = config.system.build.uki;
      imagePath = "${config.system.build.diskImage}/image.raw";
    };
  };
}
