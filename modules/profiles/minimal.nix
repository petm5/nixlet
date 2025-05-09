{ config, pkgs, modulesPath, ... }: {

  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/perlless.nix")
  ];

  # Overlays to reduce build time and closure size
  nixpkgs.overlays = [(self: super: {
    systemdUkify = self.callPackage ../../pkgs/systemd-ukify.nix { inherit super; };
    qemu_tiny = self.callPackage ../../pkgs/qemu.nix { inherit super; };
    composefs = self.callPackage ../../pkgs/composefs.nix { inherit super; };
  })];

  # Don't include kernel or modules in rootfs
  boot.kernel.enable = false;
  boot.modprobeConfig.enable = false;
  boot.bootspec.enable = false;
  system.build = { inherit (config.boot.kernelPackages) kernel; };
  system.modulesTree = [ config.boot.kernelPackages.kernel ] ++ config.boot.extraModulePackages;

  # Modules must be loaded by initrd
  boot.initrd.kernelModules = config.boot.kernelModules;

  boot.kernelModules = [
    # Required for systemd SMBIOS credential import
    "dmi_sysfs"
  ];

  # Remove foreign language support
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
  ];

  programs.nano.enable = false;

}
