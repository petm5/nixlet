{
  description = "Build OTA-updatable disk images for appliances";
  outputs = { self }: {
    nixosModules.appliance-image = import ./efi-ab-image.nix;
    nixosGenerate = {
      pkgs ? null,
      lib ? null,
      nixosSystem ? null,
      system ? null,
      modules ? []
    }: let
      image = nixosSystem {
        inherit pkgs system lib;
        modules = [
          self.nixosModules.appliance-image
        ]
        ++ modules;
      };
    in
      image.config.system.build.release;
  };
}
