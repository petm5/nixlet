{pkgs, lib, modulesPath, ...}:
{
  imports = [ (modulesPath + "/installer/cd-dvd/iso-image.nix") ];
  config = {
    isoImage = {
      volumeID = lib.mkForce "nixos";
      isoName = lib.mkForce "nixos.iso";
      makeEfiBootable = true;
      makeUsbBootable = true;
      makeBiosBootable = false;
      edition = "minimal";
    };
    boot = {
      loader.timeout = lib.mkForce 0;
      initrd.systemd.enable = lib.mkForce false; # systemd init in iso is broken, see https://github.com/NixOS/nixpkgs/issues/217173
    };
  };
}
