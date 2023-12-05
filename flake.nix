{
  description = "A minimal server image";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  };
  outputs = { self, nixpkgs }: rec {
    nixosConfigurations.iso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/iso-image.nix"
        "${nixpkgs}/nixos/modules/profiles/image-based-appliance.nix"
        "${nixpkgs}/nixos/modules/profiles/headless.nix"
        ({pkgs, lib, ...}:
        {
          isoImage = {
            volumeID = lib.mkForce "nixos";
            isoName = lib.mkForce "nixos.iso";
            squashfsCompression = "zstd -Xcompression-level 6";
            makeEfiBootable = true;
            makeUsbBootable = true;
            makeBiosBootable = false;
            edition = "minimal";
          };
          boot = {
            loader.timeout = lib.mkForce 0;
            initrd.systemd.enable = lib.mkForce false; # systemd init in iso is broken, see https://github.com/NixOS/nixpkgs/issues/217173
          };
        })
        ./configuration.nix
      ];
    };
    images.iso = self.nixosConfigurations.iso.config.system.build.isoImage;
    packages.x86_64-linux.default = self.images.iso;
  };
}
