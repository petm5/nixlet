{ pkgs, lib, modulesPath, ... }: {

  imports = [
    ../../pkgs/default.nix
    ../profiles/image-based.nix
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  # Use the latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Use systemd-based initrd
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [ "dmi_sysfs" ];

  # Use TCP BBR
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Use nftables
  networking.nftables.enable = lib.mkDefault true;

  # Use systemd-networkd
  networking.useNetworkd = true;
  systemd.network.wait-online.enable = true;

  # The server is accessed via ssh, passwords are unnecessary
  users.allowNoPasswordLogin = true;

  users.mutableUsers = true;

  # The system does not need "human" users
  services.userborn.enable = false;
  systemd.sysusers.enable = true;
  systemd.services."systemd-oomd".unitConfig.After = "systemd-sysusers.service";

  # Replace sudo with doas
  security.sudo.enable = lib.mkDefault false;
  security.doas.enable = lib.mkDefault true;
  security.doas.wheelNeedsPassword = lib.mkDefault false;

  environment.systemPackages = with pkgs; [
    doas-sudo-shim
    iotop
  ];

  # Enable a basic text editor
  programs.nano.enable = false;
  programs.vim.enable = true;
  programs.vim.defaultEditor = lib.mkDefault true;

  services.openssh.enable = true;

  # Disable password auth
  services.openssh.settings.PasswordAuthentication = lib.mkDefault false;

  # Disable RSA key generation
  services.openssh.hostKeys = [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

  virtualisation.podman.enable = true;

  # TODO: Add kubelet?

  # Allow unprivileged ports
  boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = 0;
  };

  networking.firewall.enable = false;

  # Avoid conflicts with DNS servers
  # services.resolved.extraConfig = ''
  #   DNSStubListener=no
  # '';

  # Gives a performance boost on low-spec servers
  zramSwap.enable = true;
  boot.kernelModules = [ "zram" ];

  time.timeZone = "UTC";

  # The system should reboot on failure
  systemd.watchdog = {
    runtimeTime = "10s";
    rebootTime = "30s";
  };

  boot.kernelParams = [ "panic=30" "boot.panic_on_fail" "quiet" ];

  # Enable configuration on first boot
  systemd.additionalUpstreamSystemUnits = [
    "systemd-firstboot.service"
  ];

  # Remove foreign language support
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
  ];

}
