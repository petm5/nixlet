# This module creates a bootable EFI disk image containing the given NixOS
# configuration.  The derivation for the disk image will be placed in
# config.system.build.diskImage.

{ config, lib, pkgs, modulesPath, ... }:

with lib;

let

  bootLoaderConfigPath = "/loader/entries/nixos.conf";
  kernelPath = "/EFI/nixos/kernel.efi";
  initrdPath = "/EFI/nixos/initrd.efi";

  efiArch = pkgs.stdenv.hostPlatform.efiArch;

in

{
  imports = [ (modulesPath + "/image/repart.nix") ];

  config = {
    fileSystems = {
      "/" = mkImageMediaOverride
        {
          fsType = "tmpfs";
          options = [ "mode=0755" ];
        };

      # Note that /dev/root is a symlink to the actual root device
      # specified on the kernel command line, created in the stage 1
      # init script.
      "/iso" = mkImageMediaOverride
        { device = "/dev/root";
          neededForBoot = true;
          noCheck = true;
        };

      # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
      # image) to make this a live CD.
      "/nix/.ro-store" = mkImageMediaOverride
        { fsType = "squashfs";
          device = "/iso/nix-store.squashfs";
          options = [ "loop" ];
          neededForBoot = true;
        };

      "/nix/.rw-store" = mkImageMediaOverride
        { fsType = "tmpfs";
          options = [ "mode=0755" ];
          neededForBoot = true;
        };

      "/nix/store" = mkImageMediaOverride
        { fsType = "overlay";
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
    };

    # Don't build the GRUB menu builder script, since we don't need it
    # here and it causes a cyclic dependency.
    boot.loader.grub.enable = false;

    environment.systemPackages =  [ pkgs.grub2 pkgs.grub2_efi ];

    boot.initrd.availableKernelModules = [ "squashfs" "vfat" "overlay" ];

    boot.initrd.supportedFilesystems = [ "vfat" ];    
    boot.initrd.kernelModules = [ "loop" "overlay" ];

    image.repart = {
      name = "nixos";
      partitions = {
        "esp" = {
          contents = {
            "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
              "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

            "${bootLoaderConfigPath}".source = pkgs.writeText "nixos.conf" ''
              title NixOS
              linux ${kernelPath}
              initrd ${initrdPath}
              options init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
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
          storePaths = [ config.system.build.toplevel ];
          repartConfig = {
            Type = "root";
            Format = "squashfs";
            Label = "roota";
            Minimize = "guess";
          };
        };
      };
    };

    system.build.diskImage = image;
    
  };

}
