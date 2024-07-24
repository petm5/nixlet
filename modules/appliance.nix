{ config, lib, pkgs, ... }: 
let
  cfg = config.appliance;
in {

    imports = [
      ./root-in-initrd.nix
      ./profiles/ultra-minimal.nix
    ];

  options.appliance = {

    name = lib.mkOption {
      type = lib.types.str;
      default = config.system.image.id;
    };

    updates = {
      url = lib.mkOption {
        type = lib.types.str;
        description = lib.mdDoc ''
          URL used by systemd-sysupdate to fetch OTA updates
        '';
      };
    };
  
  };

  config = {

    systemd.sysupdate.enable = true;
    systemd.sysupdate.reboot.enable = lib.mkDefault true;

    systemd.sysupdate.transfers = {
      "10-uki" = {
        Transfer = {
          Verify = "no";
        };
        Source = {
          Type = "url-file";
          Path = "${cfg.updates.url}";
          MatchPattern = "${cfg.name}_@v.efi";
        };
        Target = {
          Type = "regular-file";
          Path = "/EFI/Linux";
          PathRelativeTo = "esp";
          # Boot counting is not supported yet, see https://github.com/NixOS/nixpkgs/pull/273062
          MatchPattern = ''
            ${cfg.name}_@v.efi
          '';
          Mode = "0444";
          TriesLeft = 3;
          TriesDone = 0;
          InstancesMax = 2;
        };
      };
    };

    boot.uki.name = cfg.name;

    boot.loader.grub.enable = false;

    system.build.appliance = config.system.build.uki;

  };

}
