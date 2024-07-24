{ config, lib, pkgs, modulesPath, ... }: {

  # Start out with a minimal system
  imports = [
    (modulesPath + "/profiles/image-based-appliance.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  system.etc.overlay.mutable = false;
  users.mutableUsers = false;

  # Fix boot warning
  environment.etc."machine-id".text = " ";

  # Allow hostname change
  environment.etc.hostname.mode = "0600";

  # Don't include kernel or its modules in rootfs
  boot.kernel.enable = false;
  boot.modprobeConfig.enable = false;
  boot.bootspec.enable = false;
  system.build = { inherit (config.boot.kernelPackages) kernel; };
  system.modulesTree = [ config.boot.kernelPackages.kernel ] ++ config.boot.extraModulePackages;

  # Modules must be loaded by initrd
  boot.initrd.kernelModules = config.boot.kernelModules;

  services.openssh.startWhenNeeded = true;

  programs.nano.enable = false;

  # Disable some unused systemd features
  systemd.package = pkgs.systemd.override {
    withAcl = false;
    withApparmor = false;
    withEfi = false;
    withCryptsetup = false;
    withRepart = false;
    withDocumentation = false;
    withFido2 = false;
    withFirstboot = false;
    withHomed = false;
    withRemote = false;
    withShellCompletions = false;
    withTpm2Tss = false;
    withVmspawn = false;
  };

}
