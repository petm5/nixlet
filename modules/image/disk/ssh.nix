{ config, lib, ... }: {

  options.system.image.sshKeys = {
    enable = lib.mkEnableOption "provisioning of default SSH keys from ESP";
    keys = lib.mkOption {
      type = lib.types.listOf lib.types.singleLineStr;
      default = [];
    };
  };

  config = {

    assertions = [
      { assertion = config.services.openssh.enable; message = "OpenSSH must be enabled to preseed authorized keys"; }
    ];

    systemd.services."default-ssh-keys" = lib.mkIf config.system.image.sshKeys.enable {
      script = ''
        mkdir -p /home/admin/.ssh/
        cat /efi/default-ssh-authorized-keys.txt >> /home/admin/.ssh/authorized_keys
      '';
      wantedBy = [ "sshd.service" "sshd.socket" ];
      unitConfig = {
        ConditionPathExists = [ "/home/admin" "!/home/admin/.ssh/authorized_keys" "/efi/default-ssh-authorized-keys.txt" ];
      };
    };

  };

}
