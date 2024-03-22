{ lib, pkgs, ... }: {

  boot.consoleLogLevel = 4;
  boot.kernelParams = [ "console=ttyS0" ];
  systemd.enableEmergencyMode = lib.mkForce true;
  boot.initrd.systemd.emergencyAccess = lib.mkForce true;

  users.users."nixos" = {
    isNormalUser = true;
    initialPassword = "nixos";
    group = "nixos";
    useDefaultShell = true;
    extraGroups = [ "wheel" ];
  };
  users.groups."nixos" = {};

  image.imageVariant.config = {
    image.luks.enable = false;
    systemd.sysupdate.enable = lib.mkForce false;
  };

}
