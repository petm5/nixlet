{config, pkgs, lib, modulesPath, ...}:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")
    ./release.nix
  ];
  config = {
    isoImage = {
      volumeID = lib.mkForce "${config.osName}";
      isoName = lib.mkForce "${config.osName}-${config.release}.iso";
      makeEfiBootable = true;
      makeUsbBootable = true;
      makeBiosBootable = true;
      edition = "minimal";
    };
    boot = {
      loader.timeout = lib.mkForce 0;
      initrd.systemd.enable = lib.mkForce false; # systemd init in iso is broken, see https://github.com/NixOS/nixpkgs/issues/217173
    };
  };
}
