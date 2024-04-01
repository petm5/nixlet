{ stdenv, lib
, linux-firmware
, fwDirs
}: stdenv.mkDerivation {
  pname = "linux-firmware-minimal";
  version = linux-firmware.version;
  buildCommand = lib.concatStringsSep "\n" (
  [''mkdir -p "$out/lib/firmware"'']
  ++ (map (name: ''
    cp -r "${linux-firmware}/lib/firmware/${name}" "$out/lib/firmware/${name}"
  '') fwDirs));
}
