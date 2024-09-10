{ config, lib, pkgs, modulesPath, ... }: let

  inherit (pkgs.stdenv.hostPlatform) efiArch;

in {

  imports = [
    (modulesPath + "/image/repart.nix")
    ./updater.nix
    ./ssh.nix
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
      "20-root-a" = {
        storePaths = [ config.system.build.toplevel ];
        repartConfig = {
          Type = "root";
          Minimize = "best";
          Label = "root-${config.system.image.version}";
          Format = "erofs";
          SplitName = "root";
          MakeDirectories = "/home /root /etc /dev /sys /bin /var /proc /run /usr /srv /tmp /mnt /lib /efi";
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
        name = "${config.system.image.id}_${config.system.image.version}.root";
        path = "${config.system.build.image}/${config.image.repart.imageFileBasename}.root.raw";
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
    "20-root-a" = {
      Type = "root";
      SizeMinBytes = "512M";
      SizeMaxBytes = "512M";
    };
    "21-root-b" = {
      Type = "root";
      SizeMinBytes = "512M";
      SizeMaxBytes = "512M";
      Label = "_empty";
    };
    "30-home" = {
      Type = "home";
      Format = "btrfs";
      SizeMinBytes = "512M";
      Encrypt = "tpm2";
    };
  };

  # Should already be set by nixpkgs
  # boot.initrd.systemd.services.systemd-repart.after = lib.mkForce [ "sysroot.mount" ];
  # boot.initrd.systemd.services.systemd-repart.requires = [ "sysroot.mount" ];

  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = [ "-6" ];

  boot.loader.grub.enable = false;

  boot.initrd.luks.forceLuksSupportInInitrd = true;
  boot.initrd.kernelModules = [ "dm-crypt" ];

  # system.etc.overlay.mutable = true;

  boot.initrd.supportedFilesystems = {
    btrfs = true;
    erofs = true;
  };

  system.etc.overlay.mutable = false;
  users.mutableUsers = false;

  boot.initrd.systemd.root = "gpt-auto";

  boot.kernelParams = [ "rootfstype=erofs" "rootflags=ro" ];

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

}
