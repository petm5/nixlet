{
  description = "Build OTA-updatable disk images for appliances";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/23.11";
  };
  outputs = { self, nixpkgs }: {
    nixosGenerate = {
      pkgs ? null,
      lib ? nixpkgs.lib,
      nixosSystem ? nixpkgs.lib.nixosSystem,
      system ? null,
      modules ? []
    }: let
      formatModule = ./efi-ab-image.nix;
      image = nixosSystem {
        inherit pkgs system lib;
        modules = [
          formatModule
        ]
        ++ modules;
      };
    in
      image.config.system.build.diskImage;
  };
}
