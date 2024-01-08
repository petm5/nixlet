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

  users.allowNoPasswordLogin = true;

  boot.initrd = {
    availableKernelModules = [ "erofs" "overlay" "btrfs" ];
    kernelModules = [ "loop" "overlay" ];

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
  ];

  boot.loader.grub.enable = false;

  systemd.enableEmergencyMode = lib.mkForce true;

  users.users.root.password = "changeme";

  systemd.services."serial-getty@ttyS0".enable = true;

  # Record some image info in /etc/os-release
  environment.etc."os-release".text = lib.mkAfter ''
    IMAGE_VERSION=${config.release}
    IMAGE_ID=${config.osName}
  '';

  # Define partitions to mount
  fileSystems = {
    "/" = {
      fsType = "erofs";
      device = "${partlabelPath}/${toString version}";
    };

    "/boot" = {
      fsType = "vfat";
      device = "${partlabelPath}/esp";
    };

    "/home" = {
      fsType = "btrfs";
      device = "${partlabelPath}/${cfg.homeLabel}";
      options = [ "compress=zstd:4" ];
    };
  };

  # Expand the image on first boot
  systemd.repart = {
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
          MatchPattern = "${config.osName}_@v.erofs";
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
