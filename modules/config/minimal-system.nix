{ config, lib, pkgs, ... }: {

  options.environment.minimal = lib.mkEnableOption "minimal system components";

  config = lib.mkIf config.environment.minimal {
  
    nixpkgs.overlays = [(self: super: {

      util-linux = super.util-linux.override {
        ncursesSupport = false;
        nlsSupport = false;
      };

    })
    (self: super: {

      systemd = self.callPackage ../../pkgs/systemd.nix { inherit super; };

      systemdMinimal = self.systemd;
      systemdLibs = self.systemd;

      systemdUkify = self.callPackage ../../pkgs/systemd-ukify.nix { inherit super; };

      qemu_kvm = self.callPackage ../../pkgs/qemu.nix { inherit super; };

      qemu_test = super.qemu_kvm;

      openssh = self.callPackage ../../pkgs/openssh.nix { inherit super; };

      composefs = self.callPackage ../../pkgs/composefs.nix { inherit super; };

    })];

    # The base systemd package does not contain systemd-boot
    boot.uki.settings.UKI.Stub = "${pkgs.systemdUkify}/lib/systemd/boot/efi/linux${pkgs.stdenv.hostPlatform.efiArch}.efi.stub";

  };

}
