#! /usr/bin/env nix-shell
#! nix-shell -i bash -p efitools

mkdir signed
cp -L result/* signed/

losetup -P /dev/loop0 signed/*.img
mount /dev/loop0p1 /mnt -t vfat

find signed/ /mnt/ -name "*.efi" -type f -exec sbsign --key <(echo "$DB_KEY") --cert <(echo "$DB_CRT") --output {} {} \;

mkdir -p /mnt/loader/keys/nixlet
cp keys/*.auth /mnt/loader/keys/nixlet/

umount /mnt
losetup -d /dev/loop0
