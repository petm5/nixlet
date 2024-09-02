{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    ./network.nix
  ];

  boot.kernel.minimalModules = true;

  services.openssh.enable = true;

}
