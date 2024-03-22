{ config, extendModules, lib, ... }: let

  imageVariant = extendModules {
    modules = [ ./image.nix ];
  };

in {

  options.image.imageVariant = lib.mkOption {
    description = "Machine configuration to be added for the image variant";
    inherit (imageVariant) type;
    default = {};
    visible = "shallow";
  };

  config.system.build.image-release = lib.mkDefault config.image.imageVariant.system.build.image-release;

}
