{ config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) efiArch;
  inherit (config.image.repart.verityStore) partitionIds;
in {
  assertions = [
    { assertion = config.boot.initrd.systemd.enable; }
  ];

  fileSystems."/nix/store" = {
    device = "/usr/nix/store";
    options = [ "bind" ];
  };

  boot.kernelParams = [ "mount.usrfstype=erofs" "mount.usrflags=ro" ];

  image.repart = {
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

    mkfsOptions.erofs = [ "-zlz4hc,12" "-C1048576" "-Efragments,dedupe,ztailpacking" ];
  };
}
