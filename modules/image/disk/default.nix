{ config, lib, pkgs, modulesPath, ... }: let

  inherit (pkgs.stdenv.hostPlatform) efiArch;

in {

  imports = [
    (modulesPath + "/image/repart.nix")
    ./updater.nix
    ./ssh.nix
    ./encrypt.nix
  ];

  image.repart = {
    split = true;
    mkfsOptions.erofs = [ "-zlz4hc,level=12" "-Efragments,dedupe,ztailpacking" ];
    partitions = {
      "10-esp" = {
        contents = {
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
            "${pkgs.systemdUkify}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          "/default-ssh-authorized-keys.txt" = lib.mkIf config.system.image.sshKeys.enable {
            source = pkgs.writeText "ssh-keys" (lib.concatStringsSep "\n" config.system.image.sshKeys.keys);
          };
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = "96M";
          SizeMaxBytes = "96M";
          SplitName = "-";
        };
      };
      "20-store-a" = {
        storePaths = [ config.system.build.toplevel ];
        stripNixStorePrefix = true;
        repartConfig = {
          Type = "usr";
          Minimize = "best";
          Label = "store-${config.system.image.version}";
          Format = "erofs";
          SplitName = "store";
        };
      };
    };
  };

  system.build.updatePackage = let
    files = pkgs.linkFarm "update-files" [
      {
        name = "${config.system.image.id}_${config.system.image.version}.efi";
        path = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
      }
      {
        name = "${config.system.image.id}_${config.system.image.version}.store";
        path = "${config.system.build.image}/${config.image.repart.imageFileBasename}.store.raw";
      }
      {
        name = "${config.system.image.id}_${config.system.image.version}.img";
        path = "${config.system.build.image}/${config.image.repart.imageFileBasename}.raw";
      }
    ];
  in pkgs.runCommand "update-package" {} ''
    mkdir $out
    cd $out
    cp "${files}"/* .
    ${pkgs.coreutils}/bin/sha256sum * > SHA256SUMS
  '';

  boot.initrd.systemd.enable = true;

  boot.initrd.systemd.repart.enable = true;
  systemd.repart.partitions = {
    "10-esp" = {
      Type = "esp";
      Format = "vfat";
      SizeMinBytes = "96M";
    };
    "20-store-a" = {
      Type = "usr";
      SizeMinBytes = "512M";
      SizeMaxBytes = "512M";
    };
    "21-store-b" = {
      Type = "usr";
      SizeMinBytes = "512M";
      SizeMaxBytes = "512M";
      Label = "_empty";
    };
    "30-root" = {
      Type = "root";
      Format = "btrfs";
      SizeMinBytes = "512M";
      SizeMaxBytes = "512M";
      Encrypt = lib.mkIf config.system.image.encrypt "tpm2";
    };
    "40-home" = {
      Type = "home";
      Format = "btrfs";
      Encrypt = lib.mkIf config.system.image.encrypt "tpm2";
    };
  };

  boot.initrd.systemd.services.systemd-repart.after = lib.mkForce [ "sysusr-usr.mount" ];

  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = [ "-6" ];

  boot.loader.grub.enable = false;

  boot.initrd.luks.forceLuksSupportInInitrd = true;

  # system.etc.overlay.mutable = true;

  boot.initrd.supportedFilesystems = {
    btrfs = true;
    erofs = true;
  };

  boot.initrd.systemd.root = "gpt-auto";

  fileSystems."/usr" = {
    device = "PARTLABEL=store-${config.system.image.version}";
    fsType = "erofs";
    neededForBoot = true;
  };

  fileSystems."/nix/store" = {
    device = "/usr";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  boot.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859-1" ];

}
