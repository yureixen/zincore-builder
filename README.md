# Zincore Builder

Automated kernel build pipeline.

# Disclaimer

***Your warranty is now void. I am not responsible for bricked devices, dead SD cards, or you getting fired because an alarm failed to work. Please do some research if you have any concerns about features included before flashing it! YOU are choosing to make these modifications, and if you point the finger at me for messing up your device, I will laugh at you.***
<p align="right">Your typical XDA Forum Disclaimer.</p>

# Release schedule

Monthly releases. New builds are published on the [Releases](../../releases) page.

# Features

- `nsu` — default kernel
- `ksu` — ReSukiSU + SuSFS
- ThinLTO
- Latest AOSP Clang

# Compatibility

**Currently supported ROMs**
- PixelOS

**Supported device**
- Redmi Note 10 Pro / Pro Max ([`sweet`](https://www.gsmarena.com/xiaomi_redmi_note_10_pro-10662.php))

**Supported Android versions**
- Android 13 to Android 16

# Installation

### Recovery
1. Backup your current `boot` (and `dtbo` if needed).
2. Flash or sideload the zip (`adb sideload path/to/zip`).
3. Reboot to system.
4. (Optional, `ksu` only) Install the latest [ReSukiSU Manager](https://github.com/ReSukiSU/ReSukiSU/releases).

### Restore stock / previous kernel
1. Reboot to fastboot / fastbootd.
2. Flash your backup:
   ```bash
   fastboot flash boot boot.img
   fastboot flash dtbo dtbo.img
   ```
3. Reboot:
   ```bash
   fastboot reboot
   ```

# Credits
- [aosp-xiaomi](https://github.com/aosp-xiaomi/android_kernel_xiaomi_sm6150) — kernel source
- [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) — KernelSU implementation with non-GKI kernels
- [JackA1ltman](https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd) — SuSFS inline hook script & SuSFS patch for non-GKI kernels
