#!/usr/bin/env bash
# Download the pinned RV64 guest files into guest/cache/ and check their SHA-256.
# Files already present with the right hash are not downloaded again.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cache=$here/cache
mkdir -p "$cache"

# name, URL, SHA-256
files=(
  "bbl64.bin https://bellard.org/jslinux/bbl64.bin 293610cea7af6c75e4a8337e16c0d62834becbf31ffd9cca35e0c211602349db"
  "kernel-riscv64.bin https://bellard.org/jslinux/kernel-riscv64.bin 65ca70a6560a730396ab61488d1cf46089b32da5af7e535e03c180cd5bcc8e75"
  "diskimage-linux-riscv-2018-09-23.tar.gz https://bellard.org/tinyemu/diskimage-linux-riscv-2018-09-23.tar.gz 808ecc1b32efdd76103172129b77b46002a616dff2270664207c291e4fde9e14"
)

for entry in "${files[@]}"; do
  read -r name url sha <<<"$entry"
  dest=$cache/$name
  if [[ -f $dest ]] && echo "$sha  $dest" | sha256sum --check --status; then
    echo "ok       $name"
    continue
  fi
  curl -fsSL --proto '=https' -o "$dest.part" "$url"
  if ! echo "$sha  $dest.part" | sha256sum --check --status; then
    echo "MISMATCH $name: expected $sha, got $(sha256sum "$dest.part" | cut -d' ' -f1)" >&2
    exit 1
  fi
  mv "$dest.part" "$dest"
  echo "fetched  $name"
done

# The console guest: Bellard's riscv64 disk image (its own BBL, kernel and ext2 root).
disk=$cache/diskimage-linux-riscv-2018-09-23
if [[ ! -f $disk/root-riscv64.bin ]]; then
  tar -xzf "$cache/diskimage-linux-riscv-2018-09-23.tar.gz" -C "$cache" \
    diskimage-linux-riscv-2018-09-23/bbl64.bin \
    diskimage-linux-riscv-2018-09-23/kernel-riscv64.bin \
    diskimage-linux-riscv-2018-09-23/root-riscv64.bin
  echo "unpacked diskimage-linux-riscv-2018-09-23"
fi
