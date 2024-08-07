{ config, lib, pkgs, modulesPath, ... }: {

  # Start out with a minimal system
  imports = [
    (modulesPath + "/profiles/image-based-appliance.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  # system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  system.etc.overlay.mutable = false;
  users.mutableUsers = false;

  # Fix boot warning
  environment.etc."machine-id".text = " ";

  programs.nano.enable = false;

  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
  ];

  environment.minimal = true;
  boot.kernel.minimalModules = true;

}
