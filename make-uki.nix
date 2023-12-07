{pkgs, lib, stdenv
, systemd
, osName
, kernelPath
, initrdPath
, cmdline
, stubLocation ? "lib/systemd/boot/efi/linuxx64.efi.stub"
}:
stdenv.mkDerivation {
  name = "kernel.efi";

  nativeBuildInputs = with pkgs; [ 
      # mkuki requires a custom build of systemd as of now
      #(systemd.override { withUkify = true; })
      sbctl
    ];

  buildCommand =
  ''
  stubLocation="${pkgs.systemd}/${stubLocation}"

  sbctl bundle \
    -e "$stubLocation" \
    -c <(echo "${cmdline}") \
    -k "${kernelPath}" \
    -f "${initrdPath}" \
    -o <(echo "NAME=${osName}") \
    "$out"
  '';
}
