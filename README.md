# Disclaimer

***Your warranty is now void. I am not responsible for bricked devices, dead SD cards, or you getting fired because an alarm failed to work. Please do some research if you have any concerns about features included before flashing it! YOU are choosing to make these modifications, and if you point the finger at me for messing up your device, I will laugh at you.***
<p align="right">Your typical XDA Forum Disclaimer.</p>

# Release schedule

Builds are published **monthly**.  
Check the [Releases](../../releases) page for the latest zips.  
Emergency rebuilds may release if the kernel source or build dependencies change significantly.

# Features

| Build | Includes |
|-------|----------|
| **nsu** | Default kernel — no root integration |
| **ksu** | ReSukiSU + SuSFS |

# Compatibility

**Supported ROMs**
- PixelOS

**Supported Devices**
- Redmi Note 10 Pro / Pro Max ([`sweet`](https://www.gsmarena.com/xiaomi_redmi_note_10_pro-10662.php))

**Android**
- 13 – 16

# Installation

**Flash**
1. Reboot to recovery
2. Flash or sideload the zip
3. Reboot to system
4. install [ReSukiSU Manager](https://github.com/ReSukiSU/ReSukiSU/releases) if needed — `ksu` only

**Restore previous kernel**
```bash
fastboot flash boot boot.img
fastboot flash dtbo dtbo.img
fastboot reboot
```
# Credits
- [aosp-xiaomi](https://github.com/aosp-xiaomi/android_kernel_xiaomi_sm6150) — kernel source
- [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) — KernelSU for non-GKI
- [JackA1ltman](https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd) — SuSFS patches
