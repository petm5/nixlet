{ config, lib, ... }: {

  options.system.image.updates = {
    enable = lib.mkEnableOption "system updates via systemd-sysupdate" // {
      default = config.system.image.updates.url != null;
    };
    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf config.system.image.updates.enable {

    assertions = [
      { assertion = config.system.image.updates.url != null; }
    ];

    systemd.sysupdate.enable = true;
    systemd.sysupdate.reboot.enable = lib.mkDefault true;

    systemd.sysupdate.transfers = {
      "10-uki" = {
        Transfer = {
          Verify = "no";
        };
        Source = {
          Type = "url-file";
          Path = "${config.system.image.updates.url}";
          MatchPattern = "${config.boot.uki.name}_@v.efi";
        };
        Target = {
          Type = "regular-file";
          Path = "/EFI/Linux";
          PathRelativeTo = "esp";
          MatchPattern = "${config.boot.uki.name}_@v+@l-@d.efi ${config.boot.uki.name}_@v+@l.efi ${config.boot.uki.name}_@v.efi";
          Mode = "0644";
          TriesLeft = 3;
          TriesDone = 0;
          InstancesMax = 2;
        };
      };
      "20-usr-verity" = {
        Transfer = {
          Verify = "no";
        };
        Source = {
          Type = "url-file";
          Path = "${config.system.image.updates.url}";
          MatchPattern = "${config.system.image.id}_@v_@u.verity";
        };
        Target = {
          Type = "partition";
          Path = "auto";
          MatchPattern = "verity-@v";
          MatchPartitionType = "usr-verity";
          ReadOnly = 1;
        };
      };
      "22-usr" = {
        Transfer = {
          Verify = "no";
        };
        Source = {
          Type = "url-file";
          Path = "${config.system.image.updates.url}";
          MatchPattern = "${config.system.image.id}_@v_@u.usr";
        };
        Target = {
          Type = "partition";
          Path = "auto";
          MatchPattern = "usr-@v";
          MatchPartitionType = "usr";
          ReadOnly = 1;
        };
      };
    };
  };

}
