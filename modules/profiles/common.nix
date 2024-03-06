{ config, lib, pkgs, modulesPath, ... }:
{

  imports = [
    (modulesPath + "/profiles/image-based-appliance.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.enableEmergencyMode = lib.mkDefault false;
  systemd.watchdog = {
    runtimeTime = "10s";
    rebootTime = "30s";
  };

  system.etc.overlay.mutable = true;

  users.mutableUsers = lib.mkForce true;
  users.allowNoPasswordLogin = true;

  environment.etc."machine-id".text = " ";

  # Allow login on serial and tty.
  systemd.services."serial-getty@ttyS0".enable = true;
  systemd.services."getty@tty0".enable = true;

  # Use TCP BBR
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Replace sudo with doas
  security.sudo.enable = false;
  security.doas.enable = true;

  environment.systemPackages = with pkgs; [
    doas-sudo-shim
  ];

  networking.useNetworkd = true;
  systemd.network.wait-online.enable = false;

  virtualisation.vmVariant.config = {
    boot.consoleLogLevel = 4;
    boot.kernelParams = lib.mkForce [ ];
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

    diskImage.luks.enable = lib.mkForce false;
    boot.initrd.systemd.repart.enable = lib.mkForce false;
    systemd.sysupdate.enable = lib.mkForce false;

    virtualisation.graphics = false;

    virtualisation.writableStore = false;

    virtualisation.qemu = {
      package = pkgs.qemu_test;
      guestAgent.enable = false;
    };
  };

}
