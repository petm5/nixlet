{ config, lib, pkgs, ... }:

{

  systemd.package = pkgs.systemd.override {
    withFirstboot = true;
  };

  systemd.additionalUpstreamSystemUnits = [
    "systemd-firstboot.service"
    #"systemd-homed-firstboot.service"
  ];

}
