{ config, lib, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
  ];

  # HACK: Don't include kernel modules in rootfs.
  boot.kernel.enable = false;
  boot.modprobeConfig.enable = false;
  boot.bootspec.enable = false;
  system.build = { inherit (config.boot.kernelPackages) kernel; };
  system.modulesTree = [ config.boot.kernelPackages.kernel ] ++ config.boot.extraModulePackages;
  boot.initrd.kernelModules = config.boot.kernelModules;

}
