# Results

CMP 90HX `10de:220d` / `1555`, VBIOS `94.02.74.00.07`, open 610.43.03, 250 W
limit. Compute was already unlocked with pearlfortune stockflow.

Locked FP32 on this card was about **0.72 TFLOPS**.

After Gen2, we ran each test long enough to sit on the power limit (a few
minutes of matmuls in total, not a quick peek). PyTorch 2.9, CUDA 12.8,
8192³ except INT32. PCIe stayed **5.0 GT/s x4**. Memory clock stayed **9501 MHz**.

| Test | Time | Rate | SM | Power | PCIe |
|---|---|---|---|---|---|
| FP32 | 78 s | 15.63 TFLOPS | 1552 MHz (1515–1710) | 247 W | 5.0 GT/s |
| TF32 | 38 s | 35.14 TFLOPS | 1486 MHz (1425–1875) | 247 W | 5.0 GT/s |
| FP16 | 23 s | 67.93 TFLOPS | 1431 MHz (1380–1875) | 245 W | 5.0 GT/s |
| BF16 | 27 s | 52.63 TFLOPS | 1542 MHz (1395–1875) | 246 W | 5.0 GT/s |
| INT8 | 33 s | 41.46 TOPS | 1653 MHz (1620–1875) | 247 W | 5.0 GT/s |
| INT32 | 5 s | 64.1 GOPS | 1826 MHz (1740–1860) | 237 W | 5.0 GT/s |
| Host → GPU | 4 s | 1.62 GB/s | 1875 MHz | 131 W | 5.0 GT/s |
| GPU → host | 4 s | 1.70 GB/s | 1875 MHz | 118 W | 5.0 GT/s |
| On-GPU copy | 4 s | 351 GB/s | 1875 MHz | 205 W | 5.0 GT/s |

Idle 91 W / 36°C. After the run 182 W / 53°C.
