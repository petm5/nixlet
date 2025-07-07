{ config, lib, pkgs, ... }: let
  finalImage = config.system.build.finalImage.override {
    split = true;
  };

  verityImgAttrs = builtins.fromJSON (builtins.readFile "${finalImage}/repart-output.json");
  # HACK: Magic indices are used to select partitions, which is error-prone
  usrAttrs = builtins.elemAt verityImgAttrs 2;
  verityAttrs = builtins.elemAt verityImgAttrs 1;

  usrUuid = usrAttrs.uuid;
  verityUuid = verityAttrs.uuid;
in {
  system.build.updatePackage = let
    updateFiles = [
      {
        name = "${config.system.image.id}_${config.system.image.version}.efi";
        path = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
      }
      {
        name = "${config.system.image.id}_${config.system.image.version}_${verityUuid}.verity";
        path = "${finalImage}/${config.image.baseName}.verity.raw";
      }
      {
        name = "${config.system.image.id}_${config.system.image.version}_${usrUuid}.usr";
        path = "${finalImage}/${config.image.baseName}.usr.raw";
      }
    ];
    createHash = { name, path }: lib.concatStringsSep "  " [ (builtins.hashFile "sha256" path) name ];
  in (pkgs.linkFarm "${config.system.build.image.pname}-update-package" (updateFiles ++ [
    {
      name = "${config.system.image.id}_${config.system.image.version}.img";
      path = "${finalImage}/${config.image.baseName}.raw";
    }
    {
      name = "SHA256SUMS";
      path = pkgs.writeText "sha256sums.txt" (lib.concatLines (map createHash updateFiles));
    }
  ]));
}
