{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    ./network.nix
  ];

  boot.kernel.minimalModules = true;

  system.etc.overlay.mutable = true;
  # users.mutableUsers = true;

  users.users."admin" = {
    isNormalUser = true;
    linger = true;
    extraGroups = [ "wheel" ];
  };

  security.doas.wheelNeedsPassword = false;

  services.openssh.enable = true;
  system.image.sshKeys.enable = true;

  virtualisation.podman.enable = true;

}
