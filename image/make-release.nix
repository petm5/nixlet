# Put everyting together into a release package

{pkgs, lib, stdenv
, version
, rootfsPath
, ukiPath
, imagePath
}:
stdenv.mkDerivation {
  name = "release";

  buildCommand = ''
    mkdir $out
    ln -s "${rootfsPath}" "$out/${version}.rootfs"
    ln -s "${ukiPath}" "$out/${version}.efi"
    ln -s "${imagePath}" "$out/${version}.img"

    cd $out
    sha256sum * > SHA256SUMS
  '';
}
