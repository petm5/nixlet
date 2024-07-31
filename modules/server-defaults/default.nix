{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    ./network.nix
  ];

  # Use latest kernel
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  boot.kernelParams = [ "quiet" "console=tty0" "console=ttyS0,115200n8" ];
  boot.consoleLogLevel = lib.mkDefault 1;

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

}
