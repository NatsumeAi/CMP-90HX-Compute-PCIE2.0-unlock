#!/usr/bin/env bash
# One crafted V67 write per module load (GA102 .07). Walks the 34-entry
# privilege-mask table compiled into 0017, then a final load for late-config.
#
# Partial-bit landings count. Do not abort on readback != 0xffffffff.
# If GSP hangs: stop. Cold power-off >= 60s. Do not stack FLR/SBR.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BDF="${CMP90_BDF:-$(lspci -Dnn | awk '/10de:220d/ {print $1; exit}')}"
POKE="${CMP90_POKE:-${SCRIPT_DIR}/bar0rw}"
IDXFILE=/var/lib/cmpunlocker-rs/gen2-idx
KVER="$(uname -r)"
KO="${CMP90_NVIDIA_KO:-/lib/modules/${KVER}/updates/cmpunlocker-90hx-stockflow/nvidia.ko}"
LOG="${CMP90_CONSUME_LOG:-/var/log/cmp90hx-gen2-consume.log}"

TABLE_ADDR=(
    0x00088fe8 0x00088fec 0x00088ff0 0x00088ff4 0x00088ff8 0x00088ab4
    0x0008e1b0 0x0008e1b4 0x0008e1b8 0x0008e1bc 0x0008e1c0 0x0008e1c4
    0x0008e1c8 0x0008e1cc 0x0008e1d0 0x0008e1d4 0x0008e1d8 0x0008e1dc
    0x0008e1e0 0x0008e1e4 0x0008e1e8 0x0008e1ec 0x0008e1f0
    0x008200d0 0x008200d4 0x008200d8 0x008200dc 0x008200e0 0x008200e4
    0x008200e8 0x008200ec 0x008200f0 0x008200f4
    0x00823800
)
TABLE_SIZE=${#TABLE_ADDR[@]}

say() { echo "$*"; printf '%s\n' "$*" >>"$LOG"; }

die_hang() {
    say "HANG/ABORT: $*"
    say "Do not FLR/SBR-loop. Cold power-off the host for >= 60 seconds."
    dmesg | tail -80 >>"$LOG" || true
    exit 3
}

unload_nvidia() {
    local m
    for m in nvidia_uvm nvidia_drm nvidia_modeset nvidia_peermem nvidia; do
        if lsmod | awk '{print $1}' | grep -qx "$m"; then
            modprobe -r "$m" || { sleep 2; modprobe -r "$m" || return 1; }
        fi
    done
    ! lsmod | awk '{print $1}' | grep -qx nvidia
}

load_drm() {
    modprobe drm 2>/dev/null || true
    modprobe drm_kms_helper 2>/dev/null || true
}

write_idx() {
    mkdir -p /var/lib/cmpunlocker-rs
    printf '%u\n' "$1" >"$IDXFILE"
}

ss_zero() {
    "$POKE" "$BDF" wr 0x0082381c 0x0 >/dev/null
    "$POKE" "$BDF" wr 0x00823820 0x0 >/dev/null
}

bar0_rd() { "$POKE" "$BDF" rd "$1" 2>/dev/null || echo "unreadable"; }

classify() {
    python3 - "$1" "$2" <<'PY'
import sys
def p(s):
    s = s.strip().lower()
    if s.startswith("0x"):
        return int(s, 16)
    try:
        return int(s, 0)
    except ValueError:
        print("UNREADABLE")
        sys.exit(0)
want, got = p(sys.argv[1]), p(sys.argv[2])
if got == want:
    print("OK")
elif (got & want) == want:
    print("SUPERSET")
elif (got & want) != 0:
    print("PARTIAL")
else:
    print("NONE")
PY
}

[[ -n "$BDF" ]] || { echo "FATAL: no CMP 90HX (10de:220d); set CMP90_BDF"; exit 2; }
[[ -f "$KO" ]] || { echo "FATAL: missing $KO"; exit 2; }
[[ -x "$POKE" ]] || { echo "FATAL: missing $POKE (gcc -O2 -o bar0rw bar0rw.c)"; exit 2; }
[[ "$(id -u)" -eq 0 ]] || { echo "FATAL: run as root"; exit 2; }

mkdir -p "$(dirname "$LOG")"
: >"$LOG"
say "=== gen2-consume $(date -Is) bdf=$BDF ko=$KO table=$TABLE_SIZE ==="
sha256sum "$KO" | tee -a "$LOG"

unload_nvidia || die_hang "cannot unload nvidia stack"
feat="$(bar0_rd 0x00823804)"
say "preflight FEAT 0x823804=$feat"
[[ "$feat" == "0xffffffff" ]] || {
    say "ABORT: FEAT not open; compute unlock first"
    exit 1
}

for idx in $(seq 0 $((TABLE_SIZE - 1))); do
    addr="${TABLE_ADDR[$idx]}"
    write_idx "$idx"
    ss_zero
    before="$(bar0_rd "$addr")"
    say "[cycle $idx] addr=$addr before=$before idxfile=$(cat "$IDXFILE")"

    load_drm
    dmesg -C 2>/dev/null || true
    if ! timeout 90s insmod "$KO" "cmp90_gen2_idx=$idx"; then
        die_hang "insmod timeout/fail at idx=$idx"
    fi
    sleep 2
    timeout 30s nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1 || true

    fire="$(dmesg | grep 'GEN2CHAIN: first-fire' | tail -1 || true)"
    say "[cycle $idx] fire: ${fire:-NONE}"
    [[ -n "$fire" ]] || die_hang "no first-fire line at idx=$idx"

    unload_nvidia || die_hang "cannot unload after idx=$idx"
    after="$(bar0_rd "$addr")"
    class="$(classify 0xffffffff "$after")"
    say "[cycle $idx] after=$after class=$class"
done

write_idx "$TABLE_SIZE"
say "[late] idx=$TABLE_SIZE stock Booter + late-config (SS left full)"
load_drm
dmesg -C 2>/dev/null || true
if ! timeout 90s insmod "$KO" "cmp90_gen2_idx=$TABLE_SIZE"; then
    die_hang "insmod timeout/fail at late-config"
fi
sleep 2
timeout 30s nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1 || true
late="$(dmesg | grep -E 'late-config|50HX RETRAIN' | tail -3 || true)"
say "[late] ${late:-NO late-config line}"
say "link $(cat /sys/bus/pci/devices/${BDF}/current_link_speed 2>/dev/null) width=$(cat /sys/bus/pci/devices/${BDF}/current_link_width 2>/dev/null)"
say "Run cmp90hx-gen2-hammer.sh next if LnkSta is not yet Gen2."
say "=== done $(date -Is) ==="
