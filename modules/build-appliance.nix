{ config, extendModules, lib, ... }: let

  applianceVariant = extendModules {
    modules = [ ./appliance.nix ];
  };

in {

  options = {

    appliance.applianceVariant = lib.mkOption {
      description = ''
        Machine configuration to be added for the appliance image
      '';
      inherit (applianceVariant) type;
      default = {};
      visible = "shallow";
    };

  };
  
  config = {

    system.build = {
      appliance = lib.mkDefault config.appliance.applianceVariant.system.build.appliance;
    };

  };

}
