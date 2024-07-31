{ config, lib, pkgs, modulesPath, ... }: {

  system.build.squashfsStore = (pkgs.callPackage (modulesPath + "/../lib/make-squashfs.nix") {
    storeContents = [ config.system.build.toplevel ];
    comp = "zstd -Xcompression-level 19 -b 1M";
  });

  system.build.storeRamdisk = pkgs.makeInitrdNG {
    inherit (config.boot.initrd) compressor;
    compressorArgs = lib.optional (config.boot.initrd.compressor == "zstd") [ "-1" ];
    prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

    contents =
      [ { object = config.system.build.squashfsStore;
          symlink = "/nix-store.squashfs";
        }
      ];
  };
  
  fileSystems."/" = lib.mkForce {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  fileSystems."/nix/store" = {
    fsType = "squashfs";
    device = "/nix-store.squashfs";
    options = [ "loop" ];
    neededForBoot = true;
  };

  services.journald.storage = "volatile";

  boot.uki.settings = {
    UKI = {
      Initrd = "${config.system.build.storeRamdisk}/initrd";
    };
  };

  boot.loader.grub.enable = false;

  system.build.efi = pkgs.buildEnv {
    name = "system-image-bootloader-files";
    paths = [
      config.system.build.uki
      (pkgs.runCommand "systemd-boot" {} ''
        mkdir -p $out
        ln -s ${pkgs.systemdUkify}/lib/systemd/boot/efi/systemd-boot*.efi $out
      '')
    ];
  };

}
