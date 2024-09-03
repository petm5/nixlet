{ config, lib, pkgs, ... }: {

  nixpkgs.overlays = [(self: super: {

    systemdUkify = self.callPackage ../../pkgs/systemd-ukify.nix { inherit super; };

    qemu_tiny = self.callPackage ../../pkgs/qemu.nix { inherit super; };

    composefs = self.callPackage ../../pkgs/composefs.nix { inherit super; };

    # dbus = super.dbus.override {
    #   enableSystemd = false;
    # };

  })];

}
