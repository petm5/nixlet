{ config, lib, pkgs, modulesPath, ... }: {

  # Start out with a minimal system
  imports = [
    (modulesPath + "/profiles/image-based-appliance.nix")
    (modulesPath + "/profiles/perlless.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # system.forbiddenDependenciesRegexes = lib.mkForce [ ];

  boot.kernelModules = [
    "zram"
    "usb_storage"
    "sd_mod"
    "r8169"
  ];

  system.etc.overlay.mutable = lib.mkDefault false;
  users.mutableUsers = lib.mkDefault false;

  users.allowNoPasswordLogin = true;

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

  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
  ];

  boot.consoleLogLevel = lib.mkDefault 1;

  systemd.services."getty@tty1".enable = lib.mkDefault false;
  systemd.services."autovt@".enable = lib.mkDefault false;

  systemd.enableEmergencyMode = false;

  boot.kernelParams = [ "panic=1" "boot.panic_on_fail" "nomodeset" ];

}
