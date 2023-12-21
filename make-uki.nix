# Generate a unified kernel image with systemd-stub.
# These can be signed and verified by Secure Boot.

{pkgs, lib, stdenv
, systemd
, binutils-unwrapped-all-targets
, osName
, kernelPath
, initrdPath
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

  nativeBuildInputs = [
      systemdForImage
    ];

  buildInputs = [
      systemd
    ];

  buildCommand =
  ''
  stubLocation=("${systemd}/lib/systemd/boot/efi/linux${efiArch}.efi.stub")
  ${systemdForImage}/lib/systemd/ukify build \
    --efi-arch "${efiArch}" \
    --stub="$stubLocation" \
    --cmdline="${cmdline}" \
    --linux="${kernelPath}" \
    --os-release="NAME=${osName}" \
    --output="$out"
  '';
}
