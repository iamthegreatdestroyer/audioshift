# Frequently Asked Questions

## General

**Q: What is 432 Hz?**
A: 432 Hz is an alternative tuning frequency where A4 = 432 Hz instead of the standard 440 Hz. Some musicians and audio professionals believe it has beneficial harmonic properties.

**Q: Will this work on my device?**
A: PATH-B requires a custom ROM built for your specific device. PATH-C (Magisk module) works on most rooted Android 11+ devices. Check [DEVICE_SUPPORT.md](DEVICE_SUPPORT.md).

**Q: Is this legal?**
A: AudioShift is open-source software under the MIT license. Using it on your own device is legal. Distributing modified ROMs may have legal considerations depending on your jurisdiction.

## Technical

**Q: What's the difference between PATH-B and PATH-C?**
A: PATH-B is a custom ROM with kernel-level integration (faster, 100% coverage). PATH-C is a Magisk module that works on stock Android (easier install, 90% coverage).

**Q: Will this drain my battery?**
A: Real-time DSP processing uses CPU. Estimated battery impact is 2-5% depending on which path and your usage patterns.

**Q: Can I use this with any audio app?**
A: PATH-B covers all audio. PATH-C covers most apps but cannot intercept all VoIP calls or apps that bypass the audio system.

## Installation

**Q: Do I need to unlock my bootloader?**
A: Yes, for PATH-B (custom ROM). PATH-C only requires your device to be rooted via Magisk.

**Q: Will this void my warranty?**
A: Unlocking bootloader and flashing custom ROM will void hardware warranty. Check your device manufacturer's policy.

**Q: Can I revert to stock Android?**
A: Yes, for PATH-B you can flash the stock ROM. PATH-C can simply be uninstalled via Magisk.

## Development

**Q: How can I contribute?**
A: See [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) for setup. Submit pull requests with clear descriptions.

**Q: What's your development timeline?**
A: 10-week parallel development with phases every 2 weeks. See README for phase breakdown.

---

*(Questions will be added based on community feedback)*
