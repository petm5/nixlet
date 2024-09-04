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
        mkdir -p /root/.ssh/
        cat /efi/default-ssh-authorized-keys.txt >> /root/.ssh/authorized_keys
      '';
      wantedBy = [ "sshd.service" "sshd.socket" ];
      unitConfig = {
        ConditionPathExists = [ "!/root/.ssh/authorized_keys" "/efi/default-ssh-authorized-keys.txt" ];
      };
    };

  };

}
