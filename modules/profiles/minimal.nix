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

  systemd.package = pkgs.systemd.overrideAttrs {
    src = pkgs.fetchFromGitHub {
      owner = "petm5";
      repo = "systemd";
      rev = "c70d5474185d1bc49bdc1a5a296694ae7194c08d";
      hash = "sha256-kXySBrV/lGJD34va2oSZ67B+f+IUav1Vv9UvwLe3Z0g=";
    };
  };

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
