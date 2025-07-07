{ config, lib, pkgs, ... }: let
  modulesClosure = pkgs.makeModulesClosure {
    rootModules = config.boot.initrd.availableKernelModules ++ config.boot.initrd.kernelModules ++ config.boot.availableKernelModules ++ config.boot.kernelModules;
    kernel = config.system.modulesTree;
    firmware = config.hardware.firmware;
    allowMissing = false;
  };
in {
  options = {
    boot.availableKernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = {
    boot.kernel.enable = false;
    boot.bootspec.enable = false;

    system.build = { inherit (config.boot.kernelPackages) kernel; };
    system.modulesTree = [ config.boot.kernelPackages.kernel ] ++ config.boot.extraModulePackages;

    system.systemBuilderCommands = ''
      ln -s ${modulesClosure} $out/kernel-modules
      ln -s ${config.hardware.firmware}/lib/firmware $out/firmware
    '';
  };
}
