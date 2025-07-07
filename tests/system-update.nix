{ pkgs, self }: let

  lib = pkgs.lib;
  test-common = import ./common.nix { inherit self lib pkgs; };

  initialImage = test-common.makeImage {
    system.image.version = "1";
    nixlet.updates = {
      enable = true;
      updateUrl = "http://server.test/";
    };
  };

  updatePackage = test-common.makeUpdatePackage {
    system.image.version = "2";
  };

in test-common.makeImageTest {
  name = "system-update";
  image = initialImage;
  httpRoot = updatePackage;
  script = ''
    start_tpm()
    machine.start()

    machine.systemctl("start network-online.target")
    machine.wait_for_unit("network-online.target")

    machine.succeed("/run/current-system/sw/lib/systemd/systemd-sysupdate update")

    machine.shutdown()

    start_tpm()
    machine.start()

    machine.wait_for_unit("multi-user.target")

    machine.succeed('. /etc/os-release; [ "$IMAGE_VERSION" == "2" ]')

    machine.wait_for_unit("systemd-bless-boot.service")
  '';
}
