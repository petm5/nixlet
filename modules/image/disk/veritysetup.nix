{ config, lib, ... }: {

  options.boot.initrd.systemd.root = lib.mkOption {
    type = lib.types.enum [ "fstab" "gpt-auto" "" ];
  };

  config.boot.initrd = {

    kernelModules = [
      "dm_mod"
      "dm_verity"
    ];

   systemd = {

      # Required to activate systemd-fstab-generator
      root = "";

      additionalUpstreamUnits = [
        "veritysetup-pre.target"
        "veritysetup.target"
        "remote-veritysetup.target"
      ];

      storePaths = [
        "${config.boot.initrd.systemd.package}/lib/systemd/systemd-veritysetup"
        "${config.boot.initrd.systemd.package}/lib/systemd/system-generators/systemd-veritysetup-generator"
      ];

    };

  };

}
