{ lib, stdenv, erofs-utils, python3, xz, closureInfo
, fileName ? "erofs"
, label ? "erofs"
, storeContents ? []
}:
stdenv.mkDerivation {
  name = "${fileName}.img";

  nativeBuildInputs = [ erofs-utils xz ];

  buildCommand = ''
    echo "Creating Nix store image..."

    nixStorePaths="$TMPDIR"/nix-store-paths
    mkdir -p "$nixStorePaths"

    <${closureInfo { rootPaths = storeContents; }}/store-paths \
      xargs cp --archive --target-directory "$nixStorePaths"

    ${erofs-utils}/bin/mkfs.erofs \
      --force-uid=0 \
      --force-gid=0 \
      -L "${label}" \
      -U eb176051-bd15-49b7-9e6b-462e0b467019 \
      -T 0 \
      -b 4096 \
      -z lz4hc \
      -E fragments \
      "$out" \
      "$nixStorePaths"

    chmod +w --recursive "$nixStorePaths"
    rm -rf "$nixStorePaths"

    echo "Created Nix store image."
  '';
}
