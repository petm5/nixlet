{ config, extendModules, lib, ... }: let

  imageVariant = extendModules {
    modules = [
      ./generate.nix
    ];
  };

in {

  options.ab-image.imageVariant = lib.mkOption {
    description = "Machine configuration to be added for the image variant";
    inherit (imageVariant) type;
    default = {};
    visible = "shallow";
  };

  config.system.build.ab-image = lib.mkDefault config.ab-image.imageVariant.system.build.ab-image;

}
