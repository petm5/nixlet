{ config, lib, pkgs, ... }:

{

  # Set a default root password for initial setup.
  users.mutableUsers = lib.mkForce true;
  users.users.root.password = "changeme";
  diskImage.luks.enable = true;

  # Use for debugging only.
  # systemd.enableEmergencyMode = lib.mkForce true;
  # boot.initrd.systemd.emergencyAccess = lib.mkForce true;

  system.stateVersion = "23.11";

}
