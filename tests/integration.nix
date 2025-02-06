{ pkgs, self }: let

  lib = pkgs.lib;
  test-common = import ./common.nix { inherit self lib pkgs; };

  sshKeys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;

  initialImage = test-common.makeImage {
    system.image.sshKeys.keys = [ sshKeys.snakeOilPublicKey ];
    system.extraDependencies = [ sshKeys.snakeOilPrivateKey ];
  };

in test-common.makeImageTest {
  name = "integration";
  image = initialImage;
  script = ''
    start_tpm()
    machine.start()

    machine.wait_for_unit("multi-user.target")

    # Test SSH key provisioning functionality

    machine.succeed("[ -e /boot/default-ssh-authorized-keys.txt ]")
    machine.succeed("[ -e /root/.ssh/authorized_keys ]")

    machine.wait_for_open_port(22)

    machine.succeed(
        "cat ${sshKeys.snakeOilPrivateKey} > privkey.snakeoil"
    )
    machine.succeed("chmod 600 privkey.snakeoil")

    machine.succeed(
      "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i privkey.snakeoil root@127.0.0.1 true",
      timeout=30
    )

    machine.systemctl("start network-online.target")
    machine.wait_for_unit("network-online.target")

    # Test podman functionality

    machine.succeed("tar cv --files-from /dev/null | podman import - scratchimg")
    machine.succeed("podman run --rm -v /nix/store:/nix/store -v /run/current-system/sw/bin:/bin scratchimg true")
  '';
}
