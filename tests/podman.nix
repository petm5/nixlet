{ pkgs, self }: let

  lib = pkgs.lib;
  test-common = import ./common.nix { inherit self lib pkgs; };

  image = test-common.makeImage { };

in test-common.makeImageTest {
  name = "podman";
  inherit image;
  script = ''
    start_tpm()
    machine.start()

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("network-online.target")

    machine.succeed("tar cv --files-from /dev/null | su admin -l -c 'podman import - scratchimg'")

    machine.succeed("su admin -l -c 'podman run --rm -v /nix/store:/nix/store -v /run/current-system/sw/bin:/bin scratchimg true'")
  '';
}
