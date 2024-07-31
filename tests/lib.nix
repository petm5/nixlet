test:
{ pkgs, self }:
  let nixos-lib = import (pkgs.path + "/nixos/lib") {};
in (nixos-lib.runTest {
  hostPkgs = pkgs;
  defaults.documentation.enable = false;
  node.specialArgs = { inherit self; };
  imports = [ test ];
}).config.result
