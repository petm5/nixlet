{
  description = "Minimal image-based NixOS configuration";
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-24.05;
  };
  outputs = { self, nixpkgs }: {
    nixosModules.server-defaults = import ./modules/server-defaults;
    nixosModules.minimal-efi-bundle = import ./modules;
    checks."x86_64-linux".uefi-boot = (import ./tests/uefi-boot.nix {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      inherit self;
    });
  };
}
