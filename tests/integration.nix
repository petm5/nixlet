{ pkgs, self }: let

  lib = pkgs.lib;
  test-common = import ./common.nix { inherit self lib pkgs; };

  sshKeys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;

  initialImage = test-common.makeImage {
    system.extraDependencies = [ sshKeys.snakeOilPrivateKey ];
  };

in test-common.makeImageTest {
  name = "integration";
  image = initialImage;
  sshAuthorizedKey = sshKeys.snakeOilPublicKey;
  script = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("Verify credential provisioning functionality"):
      machine.succeed("systemd-creds --system list > /dev/console")
      machine.succeed("systemd-run -p ImportCredential=ssh.authorized_keys.root -P --wait systemd-creds cat ssh.authorized_keys.root")

      machine.succeed("[ -e /root/.ssh/authorized_keys ]")

    with subtest("Verify local SSH connection"):
      machine.wait_for_open_port(22)
      machine.succeed(
          "cat ${sshKeys.snakeOilPrivateKey} > privkey.snakeoil"
      )
      machine.succeed("chmod 600 privkey.snakeoil")
      machine.succeed(
        "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i privkey.snakeoil root@127.0.0.1 true",
        timeout=30
      )

    with subtest("Verify basic Podman functionality"):
      machine.succeed("tar cv --files-from /dev/null | podman import - scratchimg")
      machine.succeed("podman run --rm -v /nix/store:/nix/store -v /run/current-system/sw/bin:/bin scratchimg true")
  '';
}
