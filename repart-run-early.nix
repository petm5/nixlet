# Custom systemd-repart service that can handle having a tmpfs as root

{config, lib, pkgs, ...}:
let
  cfg = config.systemd.repart;
in
{
  config = {
    systemd.services.systemd-repart = {
      serviceConfig = {
        Environment = [
          "PATH=${pkgs.btrfs-progs}/bin" # Help systemd-repart to find btrfs-progs
        ];
        wantedBy = [ "local-fs-pre.target" ];
        after = [ "local-fs-pre.target" ];
      };
    };
  };
}
