# Put everyting together into a release package

{pkgs, lib, stdenv
, version
, usrPath
, ukiPath
, imagePath
}:
stdenv.mkDerivation {
  name = "release";

  buildCommand = ''
    mkdir $out
    ln -s "${usrPath}" "$out/${version}.usr"
    ln -s "${ukiPath}" "$out/${version}.efi"
    ln -s "${imagePath}" "$out/${version}.img"

    cd $out
    sha256sum * > SHA256SUMS
  '';
}
