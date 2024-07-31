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

  system.build.efi = pkgs.runCommand "system-image-bootloader-files" {} ''
    mkdir -p $out
    mkdir -p $out/EFI/BOOT
    mkdir -p $out/EFI/Linux
    ln -s ${pkgs.systemdUkify}/lib/systemd/boot/efi/systemd-boot*.efi $out/EFI/BOOT/BOOT${lib.toUpper config.nixpkgs.hostPlatform.efiArch}.EFI
    ln -s ${config.system.build.uki}/* $out/EFI/Linux/
  '';

}
