{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    ./updater.nix
    ./ssh.nix
    ./builder.nix
    ./veritysetup.nix
    ./filesystems.nix
  ];

  system.build.updatePackage = (pkgs.runCommand "update-package" {} ''
    mkdir $out
    cd $out
    cp "${config.system.build.image}"/* .
    ${pkgs.coreutils}/bin/sha256sum * > SHA256SUMS
  '') // {
    diskImage = "${config.system.build.image}/${config.system.build.image.imageFile}";
  };

  boot.initrd.systemd.enable = true;

  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = [ "-6" ];

  boot.loader.grub.enable = false;

  boot.initrd.supportedFilesystems = {
    btrfs = true;
    erofs = true;
  };

  system.etc.overlay.mutable = true;

  services.userborn.enable = false;
  systemd.sysusers.enable = true;

}
