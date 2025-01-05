{ config, lib, ... }: {

  options.system.image.sshKeys = {
    enable = lib.mkEnableOption "provisioning of default SSH keys from ESP";
    keys = lib.mkOption {
      type = lib.types.listOf lib.types.singleLineStr;
      default = [];
    };
  };

  config = lib.mkIf config.system.image.sshKeys.enable {

    assertions = [
      { assertion = config.services.openssh.enable; message = "OpenSSH must be enabled to preseed authorized keys"; }
    ];

    systemd.services."default-ssh-keys" = {
      script = ''
        mkdir -p /home/admin/.ssh/
        cat /boot/default-ssh-authorized-keys.txt >> /home/admin/.ssh/authorized_keys
      '';
      wantedBy = [ "sshd.service" "sshd.socket" ];
      unitConfig = {
        ConditionPathExists = [ "/home/admin" "!/home/admin/.ssh/authorized_keys" "/boot/default-ssh-authorized-keys.txt" ];
      };
    };

  };

}
