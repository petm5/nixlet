{ lib, pkgs, ... }: {

  boot.consoleLogLevel = 4;
  boot.kernelParams = [ "console=ttyS0" "systemd.journald.forward_to_console=1" ];
  systemd.enableEmergencyMode = true;
  boot.initrd.systemd.emergencyAccess = true;

}
