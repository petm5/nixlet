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

  systemd.services."default-ssh-keys" = {
    script = ''
      mkdir /root/.ssh
      cat /boot/default-ssh-authorized-keys.txt >> /root/.ssh/authorized_keys
    '';
    wantedBy = [ "sshd.service" "sshd.socket" ];
    unitConfig = {
      ConditionPathExists = [ "!/root/.ssh/authorized_keys" "/boot/default-ssh-authorized-keys.txt" ];
    };
  };

  systemd.services."generate-ssh-key" = {
    script = ''
      ${pkgs.openssh}/bin/ssh-keygen -f /root/.ssh/id_default -t ed25519
      cat /root/.ssh/id_default.pub > /root/.ssh/authorized_keys
      if [ -e /dev/ttyS0 ]; then
        cat /root/.ssh/id_default > /dev/ttyS0
      fi
      if [ -e /dev/tty1 ]; then
        cat /root/.ssh/id_default | ${pkgs.qrencode}/bin/qrencode -t UTF8 > /dev/tty1
      fi
    '';
    wantedBy = [ "sshd.service" "sshd.socket" ];
    conflicts = [ "default-ssh-keys.service" ];
    unitConfig = {
      ConditionPathExists = [ "!/root/.ssh/authorized_keys" ];
    };
  };

}
