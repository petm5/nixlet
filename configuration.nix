{ config, lib, pkgs, modulesPath, ... }:
let

  cfg = config.diskImage;

  partlabelPath = "/dev/disk/by-partlabel";

in

{

  imports = [
    ./image
    (modulesPath + "/profiles/image-based-appliance.nix")
    (modulesPath + "/profiles/headless.nix")
  ];

  users.allowNoPasswordLogin = true;

  boot = {
    initrd = {
      availableKernelModules = [ "squashfs" "overlay" ];
      kernelModules = [ "loop" "overlay" ];

      systemd.enable = lib.mkForce false; # See https://github.com/NixOS/nixpkgs/projects/51 and https://github.com/NixOS/nixpkgs/issues/217173
    };

    supportedFilesystems = [ "btrfs" ];

    loader.grub.enable = false;
  };

  systemd.services."serial-getty@ttyS0".enable = true;

  # Record some image info in /etc/os-release
  environment.etc."os-release".text = lib.mkAfter ''
    IMAGE_VERSION=${config.release}
    IMAGE_ID=${config.osName}
  '';

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
      options = [ "subvol=@home" ];
    };
  };


  # Help systemd to find our boot device
  # Required for systemd-repart and systemd-sysupdate to work properly
  systemd.services."link-volatile-root" = {
    description = "Register boot device on volatile root";
    script = ''
      ln -s /dev/root /run/systemd/volatile-root
    '';
    unitConfig.DefaultDependencies = false; # Prevent dependency cycle
    requiredBy = [ "local-fs.target" ];
    before = [ "local-fs.target" ];
  };

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
        Label = "${config.diskImage.homeLabel}";
        Format = "btrfs";
        FactoryReset = true;
      };
    };
  };

  # Custom systemd-repart service that can handle having a tmpfs as root
  systemd.services.systemd-repart = {
    serviceConfig = {
      Environment = [
        "PATH=${pkgs.btrfs-progs}/bin" # Help systemd-repart to find btrfs-progs
      ];
      requiredBy = [ "local-fs.target" ];
      before = [ "local-fs.target" ];
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
          # Boot counting is not supported yet, see https://github.com/NixOS/nixpkgs/pull/273062
          MatchPattern = ''
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

  system.stateVersion = "23.11";

}
