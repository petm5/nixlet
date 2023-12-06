{config, lib, pkgs, ...}:
let
  cfg = config.systemd.repart;
in
{
  options = {
    systemd.repart.device = lib.mkOption {
      type = with lib.types; nullOr str;
      description = lib.mdDoc ''
        The device to operate on.

        If `device == null`, systemd-repart will operate on the device
        backing the root partition. So in order to dynamically *create* the
        root partition in the initrd you need to set a device.
      '';
      default = null;
      example = "/dev/vda";
    };
  };

  config = {
    systemd.services.systemd-repart = {
      serviceConfig = {
        ExecStart = [
          " "
          ''
            ${config.systemd.package}/bin/systemd-repart \
              --dry-run no ${lib.optionalString (cfg.device != null) cfg.device}
          ''
        ];
        Environment = [
          "PATH=${pkgs.btrfs-progs}/bin" # HACK: Help systemd-repart to find btrfs-progs
        ];
        wantedBy = [ "local-fs-pre.target" ];
        before = [ "local-fs-pre.target" ];
      };
    };
  };
}
