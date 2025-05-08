{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    ./network.nix
  ];

  # The server is accessed via ssh, passwords are unnecessary
  users.allowNoPasswordLogin = true;

  users.mutableUsers = true;

  # Replace sudo with doas
  security.sudo.enable = lib.mkDefault false;
  security.doas.enable = lib.mkDefault true;
  security.doas.wheelNeedsPassword = lib.mkDefault false;

  environment.systemPackages = with pkgs; [
    doas-sudo-shim
    iotop
  ];

  # Enable a basic text editor
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


}
