# Help systemd to find our boot device
# cp /dev/root /run/systemd/volatile-root

{ config, ... }:
{
  systemd.services."link-volatile-root" = {
    script = ''
      ln -s /dev/root /run/systemd/volatile-root
    '';
    serviceConfig = {
      wantedBy = [ "local-fs-pre.target" ];
      before = [ "local-fs-pre.target" ];
    };
  };
}
