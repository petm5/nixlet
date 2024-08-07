{ config, lib, pkgs, ... }: 
let
  cfg = config.efi-bundle.updater;
in {

  options.efi-bundle.updater = {
    enable = lib.mkEnableOption "automatic updates";
    url = lib.mkOption {
      type = lib.types.str;
      description = "URL used by systemd-sysupdate to fetch OTA updates";
    };
  };

  config = {

    systemd.sysupdate.enable = cfg.enable;
    systemd.sysupdate.reboot.enable = lib.mkDefault true;

    systemd.sysupdate.transfers = {
      "10-uki" = {
        Transfer = {
          Verify = "no";
        };
        Source = {
          Type = "url-file";
          Path = "${cfg.url}";
          MatchPattern = "EFI/Linux/${config.boot.uki.name}_@v.efi";
        };
        Target = {
          Type = "regular-file";
          Path = "/EFI/Linux";
          PathRelativeTo = "esp";
          # Boot counting is not supported yet, see https://github.com/NixOS/nixpkgs/pull/273062
          MatchPattern = ''
            ${config.boot.uki.name}_@v.efi
          '';
          Mode = "0444";
          TriesLeft = 3;
          TriesDone = 0;
          InstancesMax = 2;
        };
      };
    };

  };

}
