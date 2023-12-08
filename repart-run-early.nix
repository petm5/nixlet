# Custom systemd-repart service that can handle having a tmpfs as root

{config, lib, pkgs, ...}:
let
  cfg = config.systemd.repart;
in
{
  config = {
    systemd.services.systemd-repart = {
      serviceConfig = {
        ExecStart = [
          " "
          ''
            ${config.systemd.package}/bin/systemd-repart \
              --dry-run no
          ''
        ];
        Environment = [
          "PATH=${pkgs.btrfs-progs}/bin" # Help systemd-repart to find btrfs-progs
        ];
        requiredBy = [ "local-fs.target" ];
        before = [ "local-fs.target" ];
      };
    };
  };
}
