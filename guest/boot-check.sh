#!/usr/bin/env bash
# Boot a pinned guest with ./temu and check it end to end. Logs and screenshots go to out/.
#
#   guest/boot-check.sh console   serial console: boot, run a command, power off
#   guest/boot-check.sh x11       X11 desktop under Xvfb: wait for Fluxbox, open its menu with
#                                 the mouse, start a terminal, type `poweroff -f` on the keyboard
#
# Success means the guest powered itself off ("Power off." from temu, exit 0) after the input.
# `x11` needs xvfb-run, xdotool and ImageMagick, and network access to vfsync.org.
# Set TEMU to test another binary.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
temu=$(realpath "${TEMU:-$root/temu}")
out=$root/out
mkdir -p "$out"
cd "$root/guest"

die() { echo "boot-check: $*" >&2; exit 1; }

console() {
  local log=$out/console.log
  # temu exits when its stdin ends, so the input is fed slowly from a subshell.
  (sleep 25; echo 'echo ARGO-$((6*7)); uname -m'; sleep 5; echo 'poweroff -f'; sleep 30) |
    timeout 90 "$temu" rv64-console.cfg >"$log" 2>&1 || true
  grep -q 'ARGO-42' "$log" || die "no command output (see $log)"
  grep -q '^riscv64' "$log" || die "uname -m is not riscv64 (see $log)"
  grep -q 'Power off.' "$log" || die "the guest did not power off (see $log)"
  echo "boot-check: console ok ($log)"
}

# The colour of pixel x,y of the screen, as `r,g,b`.
pixel() {
  import -window root "$out/screen.png"
  magick "$out/screen.png" -format "%[fx:int(255*p{$1,$2}.r)],%[fx:int(255*p{$1,$2}.g)],%[fx:int(255*p{$1,$2}.b)]" info:
}

# Run inside Xvfb, whose screen is exactly the guest's 1024x640 framebuffer.
x11_inner() {
  local log=$out/x11.log t
  TZ=UTC "$temu" rv64-xwin.cfg < <(sleep 900) >"$log" 2>&1 &
  temu_pid=$!
  trap 'kill $temu_pid 2>/dev/null || true' EXIT
  # Fluxbox is up when the wallpaper and the toolbar have their colours.
  for ((t = 0; t < 300; t += 5)); do
    sleep 5
    kill -0 $temu_pid 2>/dev/null || die "temu exited early (see $log)"
    if [[ $(pixel 300 170) == 178,178,191 && $(pixel 300 626) == 251,250,247 ]]; then break; fi
  done
  ((t < 300)) || die "no desktop after 300 s (see $out/screen.png)"
  sleep 10
  cp "$out/screen.png" "$out/x11-desktop.png"
  echo "boot-check: desktop after ~${t} s"
  # Right-click the wallpaper: Fluxbox's root menu ("Terminal" is its third item).
  xdotool mousemove 500 270 click 3
  sleep 3
  [[ $(pixel 500 310) == 244,241,236 ]] || die "no root menu after a right-click (see $out/screen.png)"
  cp "$out/screen.png" "$out/x11-menu.png"
  xdotool mousemove 474 320 click 1
  sleep 10
  import -window root "$out/x11-terminal.png"
  xdotool type --delay 100 'poweroff -f'
  xdotool key Return
  for ((t = 0; t < 90; t += 2)); do
    kill -0 $temu_pid 2>/dev/null || break
    sleep 2
  done
  wait $temu_pid 2>/dev/null || true
  grep -q 'Power off.' "$log" || die "the guest did not power off after typing poweroff -f (see $out/x11-terminal.png)"
  echo "boot-check: x11 ok ($out/x11-desktop.png, $out/x11-menu.png, $out/x11-terminal.png)"
}

x11() {
  for tool in xvfb-run xdotool import magick; do
    command -v $tool >/dev/null || die "x11 needs $tool"
  done
  xvfb-run -a -s "-screen 0 1024x640x24" "$root/guest/boot-check.sh" x11-inner
}

[[ -x $temu ]] || die "no temu at $temu: run make"
case ${1:-} in
  console) console ;;
  x11) x11 ;;
  x11-inner) x11_inner ;;
  *) die "usage: $0 console|x11" ;;
esac
