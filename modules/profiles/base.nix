{ config, lib, pkgs, modulesPath, ... }: {

  # Start out with a minimal system
  imports = [
    (modulesPath + "/profiles/image-based-appliance.nix")
    (modulesPath + "/profiles/perlless.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # boot.initrd.kernelModules = [ "virtio_net" ];

  # system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  system.etc.overlay.mutable = lib.mkDefault false;
  users.mutableUsers = lib.mkDefault false;

  programs.nano.enable = false;

  boot.tmp.useTmpfs = true;

  # Replace sudo with doas
  security.sudo.enable = lib.mkDefault false;
  security.doas.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    (lib.mkIf config.security.doas.enable doas-sudo-shim)
  ];

  services.openssh.settings.PasswordAuthentication = lib.mkDefault false;

  systemd.watchdog = lib.mkDefault {
    runtimeTime = "10s";
    rebootTime = "30s";
  };

  zramSwap.enable = true;
  boot.kernelModules = [ "zram" ];

  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
  ];

  boot.consoleLogLevel = lib.mkDefault 1;

}
