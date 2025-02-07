{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    ./network.nix
  ];

  boot.kernel.minimalModules = true;

  users.mutableUsers = lib.mkForce true;
  security.doas.wheelNeedsPassword = false;

  services.openssh.enable = true;
  system.image.sshKeys.enable = true;

  virtualisation.podman.enable = true;

  boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = 0;
  };

  networking.firewall.enable = false;

  services.resolved.extraConfig = ''
    DNSStubListener=no
  '';

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
    unitConfig = {
      ConditionPathExists = [ "!/root/.ssh/authorized_keys" ];
    };
  };

}
