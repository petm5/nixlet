# Generate a unified kernel image with systemd-stub.
# These can be signed and verified by Secure Boot.

{pkgs, lib, stdenv
, systemd
, binutils-unwrapped-all-targets
, osName
, kernelPath
, initrdPath
, cmdline
, stubLocation ? "lib/systemd/boot/efi"
}:
let
  binutils-flags = if builtins.currentSystem == "armv7l-linux" then "-b pei-arm-little" else "";
in
stdenv.mkDerivation {
  name = "kernel.efi";

  nativeBuildInputs = [ 
      # ukify requires a custom build of systemd as of now
      #(systemd.override { withUkify = true; })
      binutils-unwrapped-all-targets
    ];

  buildInputs = [
      systemd # contains the efi stub
    ];

  buildCommand =
  ''
  stubLocation=("${systemd}/${stubLocation}"/linux*.efi.stub)

  OBJCOPY="${binutils-unwrapped-all-targets}/bin/objcopy"
  OBJDUMP="${binutils-unwrapped-all-targets}/bin/objdump"

  BINFLAGS="${binutils-flags}"

  cmdlineFile=$(mktemp)
  osrelFile=$(mktemp)

  echo "${cmdline}" > $cmdlineFile
  echo "NAME=${osName}" > $osrelFile

  # HACK: Manually calculate section offsets for the EFI stub
  # This works and is future-proof, but extremely ugly
  # Adapted from https://wiki.archlinux.org/title/Unified_kernel_image#Manually

  align="$($OBJDUMP $BINFLAGS -p "$stubLocation" | awk '{ if ($1 == "SectionAlignment"){print $2} }')"
  align=$((16#$align))
  osrel_offs="$($OBJDUMP $BINFLAGS -h "$stubLocation" | awk 'NF==7 {size=strtonum("0x"$3); offset=strtonum("0x"$4)} END {print size + offset}')"
  osrel_offs=$((osrel_offs + "$align" - osrel_offs % "$align"))
  cmdline_offs=$((osrel_offs + $(stat -Lc%s "$osrelFile")))
  cmdline_offs=$((cmdline_offs + "$align" - cmdline_offs % "$align"))
  initrd_offs=$((cmdline_offs + $(stat -Lc%s "$cmdlineFile")))
  initrd_offs=$((initrd_offs + "$align" - initrd_offs % "$align"))
  linux_offs=$((initrd_offs + $(stat -Lc%s "${initrdPath}")))
  linux_offs=$((linux_offs + "$align" - linux_offs % "$align"))

  $OBJCOPY $BINFLAGS \
    --add-section .osrel="$osrelFile" --change-section-vma .osrel=$(printf 0x%x $osrel_offs) \
    --add-section .cmdline="$cmdlineFile" \
    --change-section-vma .cmdline=$(printf 0x%x $cmdline_offs) \
    --add-section .initrd="${initrdPath}" \
    --change-section-vma .initrd=$(printf 0x%x $initrd_offs) \
    --add-section .linux="${kernelPath}" \
    --change-section-vma .linux=$(printf 0x%x $linux_offs) \
    "$stubLocation" "$out"

  rm $cmdlineFile $osrelFile

  # This syntax may or may not work
  #ukify build \
  #  --cmdline="${cmdline}" \
  #  --linux="${kernelPath}" \
  #  --initrd="${initrdPath}" \
  #  --os-release="NAME=${osName}" \
  #  --output="$out"
  '';
}
