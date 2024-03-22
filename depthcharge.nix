{

  options.boot.loader.depthcharge = {
    enable = lib.mkEnableOption "Depthcharge bootloader support";

    kernelPart = lib.mkOption {
      default = "";
      type = lib.types.str;
      description = lib.mdDoc ''
        This file gets written to the ChromeOS kernel partition.
      '';
    };
  };

  config = lib.mkIf config.boot.loader.depthcharge.enable {
    image.repart.partitions."10-chromium" =  {
      repartConfig = {
        Type = "FE3A2A5D-4F32-41A7-B725-ACCC3285A309"; # ChromeOS Kernel
        Label = "KERN-A";
        SizeMinBytes = "16M";
        SizeMaxBytes = "16M";
        Flags = "0b0000000100000001000000000000000000000000000000000000000000000000"; # Prority = 1, Successful = 1
        CopyBlocks = "${config.boot.loader.depthcharge.kernelPart}";
      };
    };
  };

}
