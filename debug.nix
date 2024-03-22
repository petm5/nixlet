# Use for debugging only.
{ lib, ... }: {

  systemd.enableEmergencyMode = lib.mkForce true;
  boot.initrd.systemd.emergencyAccess = lib.mkForce true;

  users.users.root.password = "toor";

  diskImage.luks.enable = lib.mkForce false;

}
