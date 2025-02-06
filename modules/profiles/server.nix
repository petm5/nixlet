{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    ./network.nix
  ];

  boot.kernel.minimalModules = true;

  users.mutableUsers = lib.mkForce true;
  security.doas.wheelNeedsPassword = false;

  services.openssh.enable = true;
  system.image.sshKeys.enable = true;

  virtualisation.podman.enable = true;

  boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = 0;
  };

  networking.firewall.enable = false;

  services.resolved.extraConfig = ''
    DNSStubListener=no
  '';

}
