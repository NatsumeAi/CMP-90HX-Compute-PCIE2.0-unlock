# Credits

This tree is a **VBIOS 94.02.74.00.07** specialization on work that already
unlocked compute and, on other firmware revisions, PCIe Gen2.

| Who | What this patch reuses |
|---|---|
| [pearlfortune/cmpunlocker](https://github.com/pearlfortune/cmpunlocker) | 90HX stockflow / rejoin15 compute unlock (V67, SS0/SS1), 50HX Gen2 retrain shape |
| jdowning100 / rejoin16 | 34-entry PCIe privilege-mask table, in-kernel speed-path writes, `.01` / `.05` proof |
| bendy2 / amoghmunikote | 170HX Booter-time speed path |
| studebaker8/cmp170hx-gen2 | Retrain-Link hammer until LnkSta is Gen2, then stop |
| NVIDIA | Open GPU kernel modules 610.43.03 |

This repository only adds the `.07`-specific wiring (one V67 write per
module load, table consume, 50HX one-shot retrain, 170HX-style hammer)
and the measurements on that firmware.
