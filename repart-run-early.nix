# Custom systemd-repart service that can handle having a tmpfs as root

{config, lib, pkgs, ...}:
let
  cfg = config.systemd.repart;
in
{
  config = {
    systemd.services.systemd-repart = {
      serviceConfig = {
        #ExecStart = [
        #  " "
        #];
        Environment = [
          "PATH=${pkgs.btrfs-progs}/bin" # Help systemd-repart to find btrfs-progs
        ];
      };
      script = ''
        ln -s /dev/root /run/systemd/volatile-root
        ${config.systemd.package}/bin/systemd-repart \
          --dry-run no
        '';
      wantedBy = [ "local-fs.target" ];
      before = [ "local-fs-pre.target" ];
    };
  };
}
