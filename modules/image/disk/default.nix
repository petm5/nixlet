{ config, lib, pkgs, modulesPath, ... }: let

  inherit (pkgs.stdenv.hostPlatform) efiArch;

  defaultSshKeys = pkgs.writeText "ssh-keys" ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMjg1Y1b2YyhoC73I4is0/NRmVb3FeRmpLf2Yk8adrxq petms@peter-pc
  '';

in {

  imports = [
    (modulesPath + "/image/repart.nix")
    ./updater.nix
  ];

  image.repart = {
    split = true;
    mkfsOptions.squashfs = [ "-comp zstd" "-Xcompression-level 19" "-b 1M" ];
    partitions = {
      "10-esp" = {
        contents = {
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
            "${pkgs.systemdUkify}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          "/default-ssh-authorized-keys.txt".source = "${defaultSshKeys}";
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
          SizeMaxBytes = "256M";
          Label = "store-${config.system.image.version}";
          Format = "squashfs";
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
        name = "${config.system.image.id}_${config.system.image.version}.squashfs";
        path = "${config.system.build.image}/${config.image.repart.imageFileBasename}.store.raw";
      }
    ];
  in pkgs.runCommand "update-package" {} ''
    mkdir $out
    cd $out
    cp "${files}"/* .
    ${pkgs.coreutils}/bin/sha256sum * > SHA256SUMS
  '';

  systemd.services."provision-ssh-keys" = lib.mkIf config.services.openssh.enable {
    script = ''
      mkdir -p /root/.ssh/
      cat /efi/default-ssh-authorized-keys.txt >> /root/.ssh/authorized_keys
    '';
    wantedBy = [ "sshd.service" "sshd.socket" ];
    unitConfig = {
      ConditionPathExists = [ "!/root/.ssh/authorized_keys" "/efi/default-ssh-authorized-keys.txt" ];
    };
  };

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
      SizeMinBytes = "256M";
      SizeMaxBytes = "256M";
    };
    "21-store-b" = {
      Type = "usr";
      SizeMinBytes = "256M";
      SizeMaxBytes = "256M";
      Label = "_empty";
    };
    "30-root" = {
      Type = "root";
      Format = "btrfs";
      SizeMinBytes = "512M";
      SizeMaxBytes = "512M";
      Encrypt = "tpm2";
    };
    "40-home" = {
      Type = "home";
      Format = "btrfs";
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
    squashfs = true;
  };

  boot.initrd.systemd.root = "gpt-auto";

  fileSystems."/usr" = {
    device = "PARTLABEL=store-${config.system.image.version}";
    fsType = "squashfs";
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
