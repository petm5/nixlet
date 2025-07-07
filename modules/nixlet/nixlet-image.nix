{ config, lib, pkgs, modulesPath, ... }: let
    inherit (pkgs.stdenv.hostPlatform) efiArch;
    inherit (config.image.repart.verityStore) partitionIds;
    cfg = config.nixlet;
in {
  imports = [
    (modulesPath + "/image/repart.nix")
    ./update-package.nix
    ../system/kernel.nix
    ../system/network.nix
    ./nixlet-config.nix
  ];

  options.nixlet = {
    updates = {
      enable = lib.mkEnableOption "OTA updates via systemd-sysupdate";
      updateUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
    encrypt = lib.mkEnableOption "TPM-backed user data encryption" // {
      default = true;
    };
    compress = lib.mkEnableOption "store compression" // {
      default = true;
    };
  };

  config = {
    # System cannot be rebuilt
    nix.enable = false;
    system.switch.enable = false;

    nixpkgs.flake.setNixPath = false;
    nixpkgs.flake.setFlakeRegistry = false;

    # Use systemd-boot
    boot.loader.grub.enable = false;
    boot.loader.systemd-boot.enable = true;

    # Use systemd-based initrd
    boot.initrd.systemd.enable = true;

    fileSystems = {
      # Bind-mount usr to the nix store
      "/nix/store" = {
        device = "/usr/nix/store";
        options = [ "bind" ];
      };
    };

    # Auto-detect root partition
    boot.initrd.systemd.root = "gpt-auto";

    boot.kernelParams = [
      "rootfstype=btrfs" "rootflags=rw"
      "mount.usrfstype=erofs" "mount.usrflags=ro"
    ];

    boot.initrd.supportedFilesystems = {
      btrfs = true;
    };

    boot.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859-1" ];

    boot.initrd.systemd.additionalUpstreamUnits = [ "initrd-usr-fs.target" ];

    systemd.additionalUpstreamSystemUnits = [
      "systemd-bless-boot.service"
      "boot-complete.target"
    ];

    boot.initrd.systemd.services = {
      systemd-repart.after = lib.mkForce [ ];
    };

    boot.initrd.compressor = "zstd";
    boot.initrd.compressorArgs = [ (if cfg.compress then "-6" else "-1") ];

    image.repart = {
      mkfsOptions.erofs = lib.mkIf cfg.compress [ "-zlz4hc,12" "-C1048576" "-Efragments,dedupe,ztailpacking" ];

      verityStore.enable = true;

      partitions = {
        ${partitionIds.esp} = {
          contents = {
            # Include systemd-boot
            "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
              "${pkgs.systemdUkify}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          };
          repartConfig = {
            Type = "esp";
            Format = "vfat";
            SizeMinBytes = "96M";
            SplitName = "-";
          };
        };
        ${partitionIds.store-verity}.repartConfig = {
          SizeMinBytes = "64M";
          SizeMaxBytes = "64M";
          Label = "verity-${config.system.image.version}";
          SplitName = "verity";
          ReadOnly = 1;
        };
        ${partitionIds.store}.repartConfig = {
          Minimize = "best";
          Label = "usr-${config.system.image.version}";
          SplitName = "usr";
          ReadOnly = 1;
        };
      };
    };

    # Expand the image on first boot
    boot.initrd.systemd.repart.enable = true;
    systemd.repart.partitions = {
      "10-esp" = {
        Type = "esp";
        Format = "vfat";
        SizeMinBytes = "96M";
        SizeMaxBytes = "96M";
      };
      "20-usr-verity-a" = {
        Type = "usr-verity";
        SizeMinBytes = "64M";
        SizeMaxBytes = "64M";
      };
      "22-usr-a" = {
        Type = "usr";
        SizeMinBytes = "512M";
        SizeMaxBytes = "512M";
      };
      "30-usr-verity-b" = {
        Type = "usr-verity";
        SizeMinBytes = "64M";
        SizeMaxBytes = "64M";
        Label = "_empty";
        ReadOnly = 1;
      };
      "32-usr-b" = {
        Type = "usr";
        SizeMinBytes = "512M";
        SizeMaxBytes = "512M";
        Label = "_empty";
        ReadOnly = 1;
      };
      "40-state" = {
        Type = "root";
        Format = "btrfs";
        SizeMinBytes = "16M";
        SizeMaxBytes = "512M";
        Encrypt = lib.optionalString cfg.encrypt "tpm2";
        MakeDirectories = "/usr /etc /root /srv /var";
      };
      "50-home" = {
        Type = "home";
        Format = "btrfs";
        SizeMinBytes = "16M";
        Encrypt = lib.optionalString cfg.encrypt "tpm2";
      };
    };

    # Don't wait for TPM with encryption disabled
    boot.initrd.systemd.tpm2.enable = cfg.encrypt;
    systemd.tpm2.enable = true;

    boot.initrd.luks.forceLuksSupportInInitrd = true;
    boot.initrd.kernelModules = [ "dm_mod" "dm_crypt" ] ++ config.boot.initrd.luks.cryptoModules;

    # BUG: mkfs.btrfs hangs when trying to discard an encrypted partition.
    boot.initrd.systemd.services.systemd-repart.serviceConfig.Environment = [
      "SYSTEMD_REPART_MKFS_OPTIONS_BTRFS=--nodiscard"
    ];

    # Measure UEFI settings (PCR 3), Secure Boot policy (PCR 7), system extensions (PCR 13)
    boot.initrd.systemd.services.systemd-repart.serviceConfig.ExecStart = lib.mkForce [
      " "
      ''
        ${config.boot.initrd.systemd.package}/bin/systemd-repart \
                          --definitions=/etc/repart.d \
                          --dry-run=no
                          --tpm2-pcrs=3,7,13
      ''
    ];

    systemd.sysupdate = lib.mkIf cfg.updates.enable {
      enable = true;
      reboot.enable = lib.mkDefault true;
      transfers = lib.mapAttrs (name: item: lib.mkMerge [ item ({
        Transfer = {
          Verify = "no";
        };
        Source = {
          Path = "${cfg.updates.updateUrl}";
        };
      }) ]) ({
        ${partitionIds.esp} = {
          Source = {
            Type = "url-file";
            MatchPattern = "${config.boot.uki.name}_@v.efi";
          };
          Target = {
            Type = "regular-file";
            Path = "/EFI/Linux";
            PathRelativeTo = "esp";
            MatchPattern = "${config.boot.uki.name}_@v+@l-@d.efi ${config.boot.uki.name}_@v+@l.efi ${config.boot.uki.name}_@v.efi";
            Mode = "0444";
            TriesLeft = 3;
            TriesDone = 0;
            InstancesMax = 2;
          };
        };
        ${partitionIds.store-verity} = {
          Source = {
            Type = "url-file";
            MatchPattern = "${config.system.image.id}_@v_@u.verity";
          };
          Target = {
            Type = "partition";
            Path = "auto";
            MatchPattern = "verity-@v";
            MatchPartitionType = "usr-verity";
            ReadOnly = 1;
          };
        };
        ${partitionIds.store} = {
          Source = {
            Type = "url-file";
            MatchPattern = "${config.system.image.id}_@v_@u.usr";
          };
          Target = {
            Type = "partition";
            Path = "auto";
            MatchPattern = "usr-@v";
            MatchPartitionType = "usr";
            ReadOnly = 1;
          };
        };
      });
    };

  };

}
