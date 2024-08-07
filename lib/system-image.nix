{ config, lib, pkgs, ... }: {

  system.build.squashfsStore = (pkgs.callPackage (modulesPath + "/../lib/make-squashfs.nix") {
    storeContents = [ config.system.build.toplevel ];
    comp = "zstd -Xcompression-level 19 -b 1M";
  });

}
