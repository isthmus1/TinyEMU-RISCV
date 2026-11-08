#
# TinyEMU
#
# Copyright (c) 2016-2018 Fabrice Bellard
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

# TinyEMU-RISCV: the RV64 emulator only, built on a Linux host.

# Network filesystem: HTTP-backed 9P root and block devices. Needs libcurl
# and libcrypto (OpenSSL). The JSLinux X Window guest's root filesystem is
# served this way.
CONFIG_FS_NET=y
# SDL2 display, keyboard and mouse.
CONFIG_SDL=y
# Accept a gzip-compressed cpio initramfs. Needs zlib.
CONFIG_COMPRESSED_INITRAMFS=y

CC=gcc
STRIP=strip
override CFLAGS+=-O2 -Wall -g -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -MMD
override CFLAGS+=-D_GNU_SOURCE -DCONFIG_VERSION=\"$(shell cat VERSION)\"
LDFLAGS=

bindir=/usr/local/bin
INSTALL=install

PROGS=temu

all: $(PROGS)

EMU_OBJS:=virtio.o pci.o fs.o cutils.o iomem.o simplefb.o \
    json.o machine.o temu.o elf.o fs_disk.o \
    riscv_machine.o riscv_cpu.o softfp.o
EMU_LIBS=-lrt

ifdef CONFIG_FS_NET
override CFLAGS+=-DCONFIG_FS_NET
EMU_OBJS+=fs_net.o fs_wget.o fs_utils.o block_net.o
EMU_LIBS+=-lcurl -lcrypto
endif # CONFIG_FS_NET

ifdef CONFIG_SDL
override CFLAGS+=-DCONFIG_SDL
EMU_OBJS+=sdl.o
EMU_LIBS+=-lSDL2
endif # CONFIG_SDL

ifdef CONFIG_COMPRESSED_INITRAMFS
override CFLAGS+=-DCONFIG_COMPRESSED_INITRAMFS
EMU_OBJS+=compress.o
EMU_LIBS+=-lz
endif # CONFIG_COMPRESSED_INITRAMFS

temu: $(EMU_OBJS)
	$(CC) -o $@ $^ $(EMU_LIBS) $(LDFLAGS)

install: $(PROGS)
	$(STRIP) $(PROGS)
	$(INSTALL) -m755 $(PROGS) "$(DESTDIR)$(bindir)"

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f *.o *.d *~ $(PROGS)

-include $(wildcard *.d)
