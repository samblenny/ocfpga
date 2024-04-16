<!-- SPDX-License-Identifier: CC-BY-SA-4.0 or MIT -->
<!-- SPDX-FileCopyrightText: Copyright 2024 Sam Blenny -->
# 01 Smoke Test

Goal here was to smoke test my new OrangeCrab 85F board. Result is that the
board appears to be working fine with no obvious hardware faults. The charge
LED lights up green, the RGB LED cycles through a few colors, and the
surface temperatures seem reasonable.

<!-- This link is a video player for a copy of ./01_smoke_test_480p.mp4 -->
https://github.com/samblenny/ocfpga/assets/68084116/18302835-a04e-4eb0-a9c5-39e0e555e317


## Thermal

1. Ambient before power-up:

   ![Thermal image showing ambient temperature 75F](ir1__-0m14s_75F_ambient.jpg)

2. Powerup +0m13s:

   ![Thermal image showing max temp is 81F](ir2__+0m13s_81F.jpg)

3. Powerup +2m03s:

   ![max temp is 87F](ir3__+2m03s_87F.jpg)

4. Powerup +2m29s (bottom of board):

   ![max temp is 85F](ir4__+2m29s_85F_underside.jpg)

5. Powerup +3m54s:

   ![max temp is 90F](ir5__+3m54s_90F.jpg)

6. Powerup +20m09s:

   ![max temp is 93F](ir6__+20m09s_93F.jpg)


## Visible

The board looks like this with a regular camera:

![OrangeCrab 85F dev board mounted to Tamiya Universal Plate](oc-smoke-test.jpeg)
