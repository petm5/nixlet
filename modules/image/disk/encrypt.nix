{ lib, ... }: {

  options.system.image.encrypt = lib.mkEnableOption "TPM-backed encryption for system and user data" // {
    default = true;
  };

}
