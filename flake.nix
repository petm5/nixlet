{
  description = "Build OTA-updatable disk images for servers";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/23.11";
  };
  outputs = { self, nixpkgs }: rec {
    nixosConfigurations.iso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./iso-image.nix
        ./configuration.nix
      ];
    };
    nixosConfigurations.img = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./efi-ab-image.nix
        ./configuration.nix
      ];
    };
    images.iso = self.nixosConfigurations.iso.config.system.build.isoImage;
    images.efi-ab = self.nixosConfigurations.img.config.system.build.diskImage;
    components.squashfs = self.nixosConfigurations.img.config.system.build.squashfsStore;
    components.uki = self.nixosConfigurations.img.config.system.build.uki;
    packages.x86_64-linux.default = self.images.iso;
  };
}
