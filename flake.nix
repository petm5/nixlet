{
  description = "A minimal server image";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  };
  outputs = { self, nixpkgs }: rec {
    nixosConfigurations.iso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        "${nixpkgs}/nixos/modules/profiles/image-based-appliance.nix"
        "${nixpkgs}/nixos/modules/profiles/headless.nix"
        ./iso-image.nix
        ./configuration.nix
      ];
    };
    nixosConfigurations.img = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        "${nixpkgs}/nixos/modules/profiles/image-based-appliance.nix"
        "${nixpkgs}/nixos/modules/profiles/headless.nix"
        ./efi-ab-image.nix
        ./configuration.nix
      ];
    };
    images.iso = self.nixosConfigurations.iso.config.system.build.isoImage;
    images.efi-ab = self.nixosConfigurations.img.config.system.build.image;
    packages.x86_64-linux.default = self.images.iso;
  };
}
