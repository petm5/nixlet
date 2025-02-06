{ config, lib, ... }: {

  boot.initrd = {

    kernelModules = [
      "dm_mod"
      "dm_verity"
    ];

   systemd = {

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
