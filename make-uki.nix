# Generate a unified kernel image with systemd-stub.
# These can be signed and verified by Secure Boot.

{pkgs, lib, stdenv
, systemd
, binutils-unwrapped-all-targets
, osName
, kernelPath
, initrdPath
, kernelVer
, cmdline
}:
let
  systemdForImage = systemd.override {
    withUkify = true;
  };
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
in
stdenv.mkDerivation {
  name = "kernel.efi";

  buildInputs = [
      systemdForImage
    ];

  buildCommand =
  ''
  stubLocation=("${systemd}/lib/systemd/boot/efi/linux${efiArch}.efi.stub")
  ${systemdForImage}/lib/systemd/ukify build \
    --efi-arch "${efiArch}" \
    --stub="$stubLocation" \
    --cmdline="${cmdline}" \
    --linux="${kernelPath}" \
    --initrd="${initrdPath}" \
    --os-release="NAME=${osName}" \
    --uname="${kernelVer}" \
    --output="$out"
  '';
}
