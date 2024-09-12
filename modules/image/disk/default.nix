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
    "20-root-verity-a" = {
      Type = "root-verity";
      SizeMinBytes = "64M";
      SizeMaxBytes = "64M";
    };
    "22-root-a" = {
      Type = "root";
      SizeMinBytes = "512M";
      SizeMaxBytes = "512M";
    };
    "30-root-verity-b" = {
      Type = "root-verity";
      SizeMinBytes = "64M";
      SizeMaxBytes = "64M";
      Label = "_empty";
      ReadOnly = 1;
    };
    "32-root-b" = {
      Type = "root";
      SizeMinBytes = "512M";
      SizeMaxBytes = "512M";
      Label = "_empty";
      ReadOnly = 1;
    };
    "40-home" = {
      Type = "home";
      Format = "btrfs";
      SizeMinBytes = "512M";
      Encrypt = "tpm2";
    };
  };

  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = [ "-6" ];

  boot.loader.grub.enable = false;

  boot.initrd.luks.forceLuksSupportInInitrd = true;
  boot.initrd.kernelModules = [ "dm-crypt" ];

  boot.initrd.supportedFilesystems = {
    btrfs = true;
    erofs = true;
  };

  system.etc.overlay.mutable = false;
  users.mutableUsers = false;

  boot.initrd.systemd.services.systemd-repart.after = lib.mkForce [ "sysroot.mount" ];
  boot.initrd.systemd.services.systemd-repart.requires = [ "sysroot.mount" ];

  boot.kernelParams = [ "rootfstype=erofs" "rootflags=ro" "roothash=${config.system.build.verityRootHash}" ];

  fileSystems."/var" = {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  # Required to mount the efi partition
  boot.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859-1" ];

  # Store SSH host keys on /home since /etc is read-only
  services.openssh.hostKeys = [{
    path = "/home/.ssh/ssh_host_ed25519_key";
    type = "ed25519";
  }];

  environment.etc."machine-id" = {
    text = "";
    mode = "0755";
  };

  # boot.initrd.systemd.storePaths = [ "${pkgs.strace}/bin/strace" ];

  # boot.initrd.systemd.services.systemd-repart.serviceConfig.ExecStart = lib.mkForce [
  #   " "
  #   ''${pkgs.strace}/bin/strace ${config.boot.initrd.systemd.package}/bin/systemd-repart \
  #       --definitions=/etc/repart.d \
  #       --dry-run=no
  #   ''
  # ];
  
  boot.initrd.systemd.services.systemd-repart.serviceConfig.Environment = [
    "SYSTEMD_LOG_LEVEL=debug"
  ];

}
