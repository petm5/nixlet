{ lib, pkgs, ... }: {

  boot.consoleLogLevel = lib.mkForce 4;
  boot.kernelParams = lib.mkForce [ "console=ttyS0" ];
  systemd.enableEmergencyMode = lib.mkForce true;
  boot.initrd.systemd.emergencyAccess = lib.mkForce true;

}
