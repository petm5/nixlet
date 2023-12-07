# Generates a GPT disk image containing a compressed rootfs.

{ config, lib, pkgs, modulesPath, ... }:

with lib;

let

  kernelPath = "/EFI/nixos/kernel.efi";
  initrdPath = "/EFI/nixos/initrd.efi";

  partlabelPath = "/dev/disk/by-partlabel";

  # TODO: Make this configurable externally
  partitionLabel = {
    current = "nixos-current";
    next = "nixos-next";
    home = "data";
  };

  efiArch = pkgs.stdenv.hostPlatform.efiArch;

in

{
  imports = [
    (modulesPath + "/image/repart.nix")
    ./custom-repart-stage2.nix
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
  };

  config = {

    boot = {
      initrd = {
        availableKernelModules = [ "squashfs" "overlay" ];
        kernelModules = [ "loop" "overlay" ];

        systemd.enable = lib.mkForce false; # Broken for now, see https://github.com/NixOS/nixpkgs/projects/51 and https://github.com/NixOS/nixpkgs/issues/217173
      };

      supportedFilesystems = [ "btrfs" ];

      loader.grub.enable = false;

      kernelParams = [
        "console=ttyS0"
      ];
    };

    systemd.services."serial-getty@ttyS0".enable = true;

    # Manually set up overlays since systemd-volatile-root is broken
    # Mostly copied from the iso builder, can probably be simplified a bit
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

      "/home" = {
        fsType = "btrfs";
        device = "${partlabelPath}/${partitionLabel.home}";
      };
    };

    system.build.squashfsStore = pkgs.callPackage (modulesPath + "/../lib/make-squashfs.nix") {
      storeContents = config.system.build.toplevel;
      comp = config.diskImage.squashfsCompression;
    };

    system.build.uki = pkgs.callPackage ./make-uki.nix {
      kernelPath = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
      initrdPath = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
      cmdline = "root=${partlabelPath}/${toString partitionLabel.next} ${toString config.boot.kernelParams}";
      osName = "NixOS";
    };

    image.repart = {
      name = "nixos";

      partitions = {
        "esp" = {
          contents = {
            "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
              "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

            "/loader/entries/current.conf".source = pkgs.writeText "nixos.conf" ''
              title NixOS Current
              linux ${kernelPath}
              initrd ${initrdPath}
              options init=${config.system.build.toplevel}/init root=${partlabelPath}/${toString partitionLabel.current} ${toString config.boot.kernelParams}
            '';

            "/loader/entries/next.conf".source = pkgs.writeText "nixos.conf" ''
              title NixOS Next
              linux ${kernelPath}.next
              initrd ${initrdPath}.next
              options init=${config.system.build.toplevel}/init root=${partlabelPath}/${toString partitionLabel.next} ${toString config.boot.kernelParams}
            '';

            "${kernelPath}".source =
              "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";

            "${initrdPath}".source =
              "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
            };
            repartConfig = {
              Type = "esp";
              Format = "vfat";
              SizeMinBytes = "96M";
            };
        };

        "root" = {
          #storePaths = [ config.system.build.toplevel ];
          repartConfig = {
            Type = "root";
            #Format = "squashfs";
            Label = "${partitionLabel.current}";
            #Minimize = "guess";
            CopyBlocks = "${config.system.build.squashfsStore}";
          };
        };
      };
    };

    system.build.diskImage = config.system.build.image;

    # Expand the image on first boot
    systemd.repart = {
      enable = true;
      device = "${partlabelPath}/${partitionLabel.current}";

      partitions = {
        # The existing root partition
        "10-root-a" = {
          Type = "root";
          Label = "${partitionLabel.current}";
          SizeMinBytes = "512M";
          SizeMaxBytes = "512M";
        };

        # Create a secondary root partition
        "20-root-b" = {
          Type = "root";
          Label = "${partitionLabel.next}";
          SizeMinBytes = "512M";
          SizeMaxBytes = "512M";
        };

        # Create a partition for persistent data
        "30-home" = {
          Type = "home";
          Label = "${partitionLabel.home}";
          Format = "btrfs";
        };
      };
    };

    #systemd.sysupdate = {
    #  enable = true;
    #  reboot.enable = true;
    #  transfers = {
    #    ""
    #  };
    #};
  };
}
