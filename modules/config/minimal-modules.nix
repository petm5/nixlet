{ config, lib, ... }: {

  options.boot.kernel.minimalModules = lib.mkEnableOption "minimal kernel modules";

  config = lib.mkIf config.boot.kernel.minimalModules {

    # Don't include kernel or its modules in rootfs
    boot.kernel.enable = false;
    boot.modprobeConfig.enable = false;
    boot.bootspec.enable = false;
    system.build = { inherit (config.boot.kernelPackages) kernel; };
    system.modulesTree = [ config.boot.kernelPackages.kernel ] ++ config.boot.extraModulePackages;

    # Modules must be loaded by initrd
    boot.initrd.kernelModules = config.boot.kernelModules;

  };

}
