#!/usr/bin/env bash
# 170HX-style: Retrain-Link until LnkSta is Gen2, then exit.
# Never Link Disable. Never config LnkCap (CAP_EXP+0c) or LnkCap2 (+2c).
# TLS is LnkCtl2 at +30.
set -uo pipefail

BDF="${CMP90_BDF:-$(lspci -Dnn | awk '/10de:220d/ {print $1; exit}')}"
[[ -n "$BDF" ]] || { echo "no CMP 90HX 10de:220d"; exit 2; }
UPSTREAM="$(basename "$(readlink -f /sys/bus/pci/devices/${BDF}/..)")"
INTERVAL="${CMP90_HAMMER_INTERVAL:-0.05}"
WAIT_GSP_S="${CMP90_WAIT_GSP_S:-90}"
LOG="${CMP90_HAMMER_LOG:-/var/log/cmp90hx-gen2.log}"
MAX_ITER="${CMP90_HAMMER_MAX:-80}"

say() { echo "$*"; printf '%s\n' "$*" >>"$LOG"; }
lnksta() { setpci -s "$BDF" CAP_EXP+12.w 2>/dev/null || echo xxxx; }
sys_speed() { cat /sys/bus/pci/devices/${BDF}/current_link_speed 2>/dev/null || echo unknown; }
gen_from_sta() {
    local s="$1"
    [[ "$s" =~ ^[[:xdigit:]]+$ ]] || { echo 0; return; }
    echo $(( 0x$s & 0xf ))
}

mkdir -p "$(dirname "$LOG")"
: >"$LOG"
say "hammer start bdf=$BDF upstream=$UPSTREAM"

ready=0
for i in $(seq 1 "$WAIT_GSP_S"); do
    if nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1; then
        ready=1
        say "gsp-ready after ${i}s"
        break
    fi
    sleep 1
done
[[ "$ready" == 1 ]] || { say "ABORT: nvidia-smi never came up"; exit 1; }

setpci -s "$BDF"      CAP_EXP+30.w=0002:000f
setpci -s "$UPSTREAM" CAP_EXP+30.w=0002:000f

sta="$(lnksta)"
say "pre-hammer LnkSta=0x${sta} gen=$(gen_from_sta "$sta") sys=$(sys_speed)"

for i in $(seq 1 "$MAX_ITER"); do
    setpci -s "$UPSTREAM" CAP_EXP+10.w=0020:0020
    sleep "$INTERVAL"
    sta="$(lnksta)"
    g="$(gen_from_sta "$sta")"
    if (( g >= 2 )); then
        say "*** GEN2 TRAINED *** iter=$i LnkSta=0x${sta} sys=$(sys_speed)"
        exit 0
    fi
done
say "FAIL: gave up after ${MAX_ITER} iterations LnkSta=0x$(lnksta)"
exit 1
