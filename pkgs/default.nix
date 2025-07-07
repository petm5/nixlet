{

  nixpkgs.overlays = [(self: super: {
    systemdUkify = self.callPackage ./systemd-ukify.nix { inherit super; };
    qemu_tiny = self.callPackage ./qemu.nix { inherit super; };
    composefs = self.callPackage ./composefs.nix { inherit super; };
  })];

}
