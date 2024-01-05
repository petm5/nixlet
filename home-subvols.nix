{ config, lib, ... }:

with lib.attrsets;
with builtins;

let

  userSubvols = let
    mkUserSubvol = u: nameValuePair "${u.home}" {
      fsType = "btrfs";
      device = "${partlabelPath}/${cfg.homeLabel}";
      options = [ "subvol=@${u.name}" ];
    };
    usersWithHomes = attrValues (filterAttrs (n: u: u.createHome) config.users.users);
  in listToAttrs (map mkUserSubvol usersWithHomes);

in
{
  config.fileSystems = userSubvols;
}
