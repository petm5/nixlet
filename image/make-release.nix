# Put everyting together into a release package

{pkgs, lib, stdenv
, version
, erofsPath
, ukiPath
, imagePath
}:
stdenv.mkDerivation {
  name = "release";

  buildCommand = ''
    mkdir $out
    ln -s "${erofsPath}" "$out/${version}.erofs"
    ln -s "${ukiPath}" "$out/${version}.efi"
    ln -s "${imagePath}" "$out/${version}.img"

    cd $out
    sha256sum * > SHA256SUMS
  '';
}
