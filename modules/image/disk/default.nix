{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    ./updater.nix
    ./ssh.nix
    ./builder.nix
    ./veritysetup.nix
  ];

  system.build.updatePackage = pkgs.runCommand "update-package" {} ''
    mkdir $out
    cd $out
    cp "${config.system.build.image}"/* .
    ${pkgs.coreutils}/bin/sha256sum * > SHA256SUMS
  '';

  boot.initrd.systemd.enable = true;

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
      Encrypt = "tpm2";
      MakeDirectories = "/usr /etc /root /srv /var";
    };
    "50-home" = {
      Type = "home";
      Format = "btrfs";
      SizeMinBytes = "16M";
      Encrypt = "tpm2";
    };
  };

  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = [ "-6" ];

  boot.loader.grub.enable = false;

  boot.initrd.luks.forceLuksSupportInInitrd = true;
  boot.initrd.kernelModules = [ "dm_mod" "dm_crypt" ] ++ config.boot.initrd.luks.cryptoModules;

  boot.initrd.supportedFilesystems = {
    btrfs = true;
    erofs = true;
  };

  system.etc.overlay.mutable = true;

  services.userborn.enable = false;
  systemd.sysusers.enable = true;

  boot.initrd.systemd.services.systemd-repart.after = lib.mkForce [ ];

  boot.kernelParams = [ "rootfstype=btrfs" "rootflags=rw" "mount.usrfstype=erofs" "mount.usrflags=ro" "usrhash=${config.system.build.verityUsrHash}" ];

  fileSystems."/nix/store" = {
    device = "/usr";
    options = [ "bind" ];
  };

  boot.initrd.systemd.root = "gpt-auto";

  boot.initrd.systemd.additionalUpstreamUnits = [ "initrd-usr-fs.target" ];

  # Required to mount the efi partition
  boot.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859-1" ];

  boot.initrd.systemd.services.systemd-repart.serviceConfig.Environment = [
    "SYSTEMD_REPART_MKFS_OPTIONS_BTRFS=--nodiscard"
  ];

  boot.initrd.systemd.services.systemd-repart.serviceConfig.ExecStart = lib.mkForce [
    " "
    ''
      ${config.boot.initrd.systemd.package}/bin/systemd-repart \
                        --definitions=/etc/repart.d \
                        --dry-run=no
                        --tpm2-pcrs=3,7,13
    ''
  ];

  services.openssh.hostKeys = [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

}
