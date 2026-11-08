# TinyEMU-RISCV

[Fabrice Bellard's TinyEMU][TinyEMU], cut down to the emulator needed to boot an **RV64 Linux X11
desktop** on a Linux host, and nothing else. It is the C baseline that the Argo project
translates to Rust. Every C file left in the tree is part of the emulator that `make` builds.

It is based on [Fernando Lemos's fork][fernandotcl] (SDL2, ELF and initrd loading), with the full
history of both kept.

[TinyEMU]: https://bellard.org/tinyemu/
[fernandotcl]: https://github.com/fernandotcl/TinyEMU

## What is in it

- RV64IMAFDC CPU with the M, S and U privilege levels and Sv39/Sv48 MMU (`riscv_cpu*`), plus
  soft-float (`softfp*`).
- The RISC-V machine (`riscv_machine.c`): RAM, CLINT, PLIC, HTIF, device tree, BIOS/kernel/initrd
  loading (`elf.c`, `compress.c`).
- VirtIO over MMIO (`virtio.c`): block, network, console, input (keyboard, mouse, tablet) and 9P.
- 9P backends: a host directory (`fs_disk.c`) and the HTTP network filesystem (`fs_net.c`,
  `fs_wget.c`, `block_net.c`, `fs_utils.c`).
- `simplefb` framebuffer and the SDL2 frontend (`sdl.c`).
- `temu.c` (command line, console, tap networking), `machine.c` (JSON configuration), `json.c`,
  `cutils.c`, `iomem.c`.

## What was removed, and why

| Removed | Why |
| --- | --- |
| x86 PC machine (x86 CPU, IDE, PS/2, i8042, vmmouse, VGA) | Only RISC-V is emulated. |
| PCI bus and VirtIO's PCI transport | Only the x86 machine used PCI; RISC-V uses virtio-mmio. |
| RV32 and RV128 | One guest: RV64 Linux. `riscv_cpu.c` is compiled once, with `MAX_XLEN` 64. |
| Run-time XLEN switching | `misa.MXL` and `mstatus.SXL/UXL` are WARL; they are now hardwired to 64, so only the 64-bit interpreter is instantiated. |
| 128-bit soft-float | Used by RV128 only. Still available with `-DCONFIG_SOFTFP_128`. |
| SLIRP user-mode networking | The desktop needs no network. The `tap` backend remains. |
| JavaScript/Emscripten, iOS, Windows and macOS builds | The baseline host is Linux. |
| `build_filelist`, `splitimg` | Standalone tools for preparing network filesystem images. |

## Fixes on top of upstream

- FMIN/FMAX follow RISC-V's IEEE 754-201x rule, ported from TinyEMU 2019-12-21. The fork was
  based on 2019-02-10.
- `fs_wget.c` builds against curl 8.x.
- `mstatus.SXL` was read from the UXL field on writes.

## Build

Needs gcc, make, libcurl, OpenSSL (libcrypto), SDL2 and zlib.

```sh
# Arch:   sudo pacman -S --needed base-devel curl openssl sdl2 zlib
# Debian: sudo apt-get install build-essential libcurl4-openssl-dev libssl-dev libsdl2-dev zlib1g-dev
make
```

## Guests

`guest/fetch.sh` downloads the guest files into `guest/cache/` and checks their SHA-256:

| File | Source | SHA-256 |
| --- | --- | --- |
| `bbl64.bin` | https://bellard.org/jslinux/bbl64.bin | `293610cea7af6c75e4a8337e16c0d62834becbf31ffd9cca35e0c211602349db` |
| `kernel-riscv64.bin` | https://bellard.org/jslinux/kernel-riscv64.bin | `65ca70a6560a730396ab61488d1cf46089b32da5af7e535e03c180cd5bcc8e75` |
| `diskimage-linux-riscv-2018-09-23.tar.gz` | https://bellard.org/tinyemu/ | `808ecc1b32efdd76103172129b77b46002a616dff2270664207c291e4fde9e14` |

Two configurations:

- `guest/rv64-xwin.cfg`: the [JSLinux RV64 X Window guest][xwin] (Fluxbox, xterm, Dillo) at
  1024x640 with VirtIO keyboard and mouse. BIOS and kernel are local. **The root filesystem is
  still served over HTTP by vfsync.org**, so it isn't hash-pinned and needs network access.
  Replacing it with a local copy would also let `fs_net.c` and its curl/OpenSSL dependency go.
- `guest/rv64-console.cfg`: Bellard's riscv64 disk image (busybox, ext2 root) on the serial
  console. Fully local.

[xwin]: https://bellard.org/jslinux/buildroot-riscv64-xwin.cfg

```sh
guest/fetch.sh
cd guest && ../temu rv64-xwin.cfg      # opens an SDL window; C-a x on the terminal quits
```

## Boot check

`guest/boot-check.sh` boots a guest headlessly and checks it end to end, saving logs and
screenshots in `out/`:

- `console`: boots to the shell, runs a command, checks its output and `uname -m`, then powers
  off.
- `x11`: runs the X11 guest under Xvfb and waits for the Fluxbox desktop. It right-clicks for the
  root menu, opens a terminal, and types `poweroff -f`. It passes when the guest powers itself
  off, which takes both pointer and keyboard input. Needs `xvfb-run`, `xdotool`, ImageMagick and
  network access.

`TEMU=/path/to/temu guest/boot-check.sh x11` checks another build, such as a partly translated
one.

## License

MIT, as upstream (see `MIT-LICENSE.txt` and the headers of individual files). TinyEMU was
created by [Fabrice Bellard](https://bellard.org). The SDL2 port and loaders are by
Fernando Tarlá Cardoso Lemos.
