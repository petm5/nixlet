{ config, lib, pkgs, ... }:

let

  minimalQemu = (pkgs.qemu_kvm.override {
    hostCpuOnly = true;
    sdlSupport = false;
    nixosTestRunner = true;
    enableDocs = false;
  }).overrideAttrs (oa: {
    postFixup = ''
      ${oa.postFixup or ""}
      ${lib.optionalString (pkgs.system != "aarch64-linux") "rm -rf $out/share/qemu/edk2-arm-*"}
    '';
  });

  minimalLibvirt = pkgs.libvirt.override {
    enableZfs = false;
  };

in

{

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    libvirtd = {
      enable = true;
      package = minimalLibvirt;
      qemu.ovmf.enable = true;
      qemu.package = minimalQemu;
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

}
