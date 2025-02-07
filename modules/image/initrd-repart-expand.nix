{ config, lib, ... }: let
  cfg = config.system.image.filesystems;
in {

  options.system.image.filesystems = {
    encrypt = lib.mkEnableOption "TPM-backed user data encryption" // {
      default = true;
    };
  };

  config = lib.mkMerge [({

    assertions = [
      { assertion = config.boot.initrd.systemd.enable; }
    ];

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

    boot.initrd.systemd.services.systemd-repart.after = lib.mkForce [ ];

    boot.initrd.supportedFilesystems.btrfs = true;

    boot.kernelParams = [ "rootfstype=btrfs" "rootflags=rw" ];

    boot.initrd.systemd.root = "gpt-auto";

    # Required to mount the efi partition
    boot.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859-1" ];

    # Don't wait for TPM with encryption disabled
    boot.initrd.systemd.tpm2.enable = !cfg.encrypt;
    systemd.tpm2.enable = !cfg.encrypt;

  }) (lib.mkIf cfg.encrypt {

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

  })];

}
