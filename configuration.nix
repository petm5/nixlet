{ config, lib, pkgs, ... }:

{

  imports = [./modules/system.nix];

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    libvirtd = {
      enable = true;
      qemu.ovmf.enable = true;
    };
  };

  services.openssh.enable = true;

  # Use systemd-homed to manage users.
  services.homed.enable = true;

  # Require both public key and password to log in via ssh.
  services.openssh = {
    authorizedKeysCommand = "/etc/ssh/authorized_keys_command_userdbctl %u";
    authorizedKeysCommandUser = "root";
    settings.PasswordAuthentication = lib.mkForce true;
    settings.AuthenticationMethods = "publickey,password";
  };

  # Home dirs are encrypted, so fetch authorized keys from userdb.
  environment.etc."ssh/authorized_keys_command_userdbctl" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      exec ${pkgs.systemd}/bin/userdbctl ssh-authorized-keys "$@"
    '';
  };

  boot.kernelParams = [
    "boot.panic_on_fail"
    "panic=5"
  ];

  systemd = {
    enableEmergencyMode = false;
    watchdog.runtimeTime = "10s";
    watchdog.rebootTime = "30s";
    sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
    '';
  };

  # Use TCP BBR
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Disable anything that we don't need to save space

  documentation.enable = lib.mkDefault false;
  documentation.info.enable = lib.mkDefault false;
  documentation.man.enable = lib.mkDefault false;
  documentation.nixos.enable = lib.mkDefault false;

  fonts.fontconfig.enable = lib.mkDefault false;

  sound.enable = false;

}
