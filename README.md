# CMP 90HX PCIe Gen2 (VBIOS 94.02.74.00.07)

## Repos we used

- Compute: [pearlfortune/cmpunlocker](https://github.com/pearlfortune/cmpunlocker) 90HX stockflow (`0001`–`0015`) on NVIDIA Open **610.43.03**
- PCIe on VBIOS `.01` / `.05`: jdowning100 rejoin16 (`0016`)
- PCIe on **`.07`**: this repo (`0017`)

## Unlock

**Compute** — follow pearlfortune’s stockflow. After that, this card went from about **0.72 TFLOPS** FP32 to the mid-teens.

**PCIe Gen2** — apply `0001`–`0016`, then `0017`, build, install the modules:

```sh
patch -p1 < patches/0017-6104303-cmp90hx-vbios07-pcie-gen2.patch
cd kernel-open
MAKEFLAGS='CC=gcc-14' make -j"$(nproc)" modules
```

Put the `.ko` files in `/lib/modules/$(uname -r)/updates/cmpunlocker-90hx-stockflow/` and run `depmod`.

After a **cold boot**, the PCIe unlock has to be applied again:

```sh
gcc -O2 -o scripts/bar0rw scripts/bar0rw.c
sudo scripts/cmp90hx-gen2-consume.sh
sudo scripts/cmp90hx-gen2-hammer.sh
```

```sh
cat /sys/bus/pci/devices/<BDF>/current_link_speed    # want 5.0 GT/s PCIe
sudo setpci -s <BDF> CAP_EXP+12.w                    # want 1042
```

If the GPU dies, power the machine off for a minute. Leave Secure Boot off. Don’t write LnkCap. Don’t use the 170HX `PL_LINK_RATE` value `0x00240036`.

`systemd/` has optional boot units; fix the paths before enabling them.

## Results

Same card, tests left running under the 250 W limit. Link stayed Gen 2. This board is **x4**.

| | |
|---|---|
| FP32 | 15.63 TFLOPS |
| FP16 | 67.93 TFLOPS |
| BF16 | 52.63 TFLOPS |
| INT8 | 41.46 TOPS |
| Copy in / out | 1.62 / 1.70 GB/s |

More in [RESULTS.md](RESULTS.md). [CREDITS.md](CREDITS.md) / [LICENSE](LICENSE).
