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
      };
      requiredBy = [ 
        ""
        "local-fs-pre.target"
      ];
      before = [
        " "
        "local-fs-pre.target"
      ];
    };
  };
}
