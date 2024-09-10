{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    ./network.nix
  ];

  boot.kernel.minimalModules = true;

  # system.etc.overlay.mutable = true;
  # users.mutableUsers = true;

  users.users."admin" = {
    isNormalUser = true;
    linger = true;
    extraGroups = [ "wheel" ];
  };

  # perlless activation doesn't seem to support subuid / subgid yet
  environment.etc."subuid" = {
    text = ''
      admin:100000:65536
    '';
    mode = "0644";
  };

  environment.etc."subgid" = {
    text = ''
      admin:100000:65536
    '';
    mode = "0644";
  };

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
