{ config, lib, pkgs, modulesPath, ... }:
let

  cfg = config.diskImage;

  version = "${config.osName}_${config.release}";

  partlabelPath = "/dev/disk/by-partlabel";

in

{

  imports = [
    ./image
    (modulesPath + "/profiles/image-based-appliance.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd = {
    availableKernelModules = [ "squashfs" "overlay" "btrfs" "usb-storage" ];
    kernelModules = [ "loop" "overlay" "usb-storage" ];
    systemd.enable = true; # See https://github.com/NixOS/nixpkgs/projects/51
    systemd.additionalUpstreamUnits = ["systemd-volatile-root.service"];
    systemd.storePaths = [
      "${config.boot.initrd.systemd.package}/lib/systemd/systemd-volatile-root"
      "${pkgs.btrfs-progs}/bin/btrfs"
      "${pkgs.btrfs-progs}/bin/mkfs.btrfs"
    ];
  };

  boot.kernelParams = [
    "systemd.volatile=overlay"
    "console=ttyS0"
    "console=tty0"
    "nomodeset" # TODO: Remove graphics drivers from the final image
  ];

  boot.loader.grub.enable = false;

  # Use for debugging only.
  #systemd.enableEmergencyMode = lib.mkForce true;
  #boot.initrd.systemd.emergencyAccess = true;

  # Set a default root password for initial setup.
  users.mutableUsers = lib.mkForce true;
  users.users.root.password = "changeme";

  # Allow login on serial and tty.
  systemd.services."serial-getty@ttyS0".enable = true;
  systemd.services."getty@tty0".enable = true;

  environment.etc."os-release".text = lib.mkAfter ''
    IMAGE_VERSION=${config.release}
    IMAGE_ID=${config.osName}
  '';

  fileSystems = {
    "/" = {
      fsType = "squashfs";
      device = "${partlabelPath}/${toString version}";
    };

    "/boot" = {
      fsType = "vfat";
      device = "${partlabelPath}/esp";
    };

    # Use bind mounts instead of subvolumes until systemd v255 is merged.

    "/data" = {
      fsType = "btrfs";
      device = "${partlabelPath}/${cfg.dataLabel}";
      options = [ "compress=zstd:4" ];
      neededForBoot = true;
    };

    "/etc" = {
      device = "/data/etc";
      options = [ "bind" ];
      depends = ["/data"];
    };

    "/var" = {
      device = "/data/var";
      options = [ "bind" ];
      depends = ["/data"];
    };

    "/home" = {
      device = "/data/home";
      options = [ "bind" ];
      depends = ["/data"];
      neededForBoot = true;
    };
  };

  systemd.repart = {
    partitions = {
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
        Label = "${config.diskImage.dataLabel}";
        Format = "btrfs";
        # Subvolume creation is not supported yet
        MakeDirectories = "/home /etc /var";
        FactoryReset = true;
        Encrypt = "tpm2";
      };
    };
  };

  boot.initrd.systemd.repart.enable = true;

  boot.initrd.systemd.services.systemd-repart = {
    serviceConfig = {
      Environment = [
        "PATH=${pkgs.btrfs-progs}/bin" # Help systemd-repart to find btrfs-progs
      ];
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
          MatchPattern = "${config.osName}_@v.rootfs";
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
