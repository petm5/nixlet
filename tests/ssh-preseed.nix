{ pkgs, self }: let

  lib = pkgs.lib;
  test-common = import ./common.nix { inherit self lib pkgs; };
  sshKeys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;

  image = test-common.makeImage {
    system.image.sshKeys.keys = [ sshKeys.snakeOilPublicKey ];
    system.extraDependencies = [ sshKeys.snakeOilPrivateKey ];
  };

in test-common.makeImageTest {
  name = "ssh-preseed";
  inherit image;
  script = ''
    start_tpm()
    machine.start()

    machine.wait_for_unit("multi-user.target")

    machine.wait_for_open_port(22)

    machine.succeed(
        "cat ${sshKeys.snakeOilPrivateKey} > privkey.snakeoil"
    )
    machine.succeed("chmod 600 privkey.snakeoil")

    machine.succeed(
      "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i privkey.snakeoil root@127.0.0.1 true",
      timeout=30
    )
  '';
}
