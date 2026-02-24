# XDA Post Template — AudioShift

<!--
  INSTRUCTIONS FOR USE
  ────────────────────
  1. Fill in every section marked with ⬛ before posting.
  2. Replace placeholder text in [square brackets].
  3. Upload screenshots to an image host (Imgur recommended) before filling
     the Screenshots section. XDA embeds images from direct URLs.
  4. Delete these instructions before posting.
  5. Post to: https://forum.xda-developers.com/f/magisk.10602/
-->

---

# [MODULE] AudioShift 432Hz — System-Wide Pitch Shift | v[VERSION] | Android [MIN_API]+

---

## 📌 Description

AudioShift is a **Magisk module** that transparently shifts all system audio output from
the ISO 440 Hz standard tuning to the historical **432 Hz** reference pitch — in real time,
system-wide, without modifying any individual app.

Every sound on your device — music, video, podcasts, notifications — is pitch-shifted down
by **−31.77 cents** (≈ −32 cents) via a lightweight SoundTouch DSP pipeline injected into
the Android audio HAL.

**Why 432 Hz?**
Before ISO 16:1955 standardised concert A at 440 Hz, European orchestras commonly tuned to
432–435 Hz. Many listeners find 432 Hz more relaxing and natural. AudioShift lets you
experience all audio at that historical reference pitch, on any app, without touching the
source files.

---

## ✅ Features

- System-wide — affects **all** audio output (music, video, calls optional)
- Real-time DSP via **SoundTouch** open-source library
- No source app modification needed
- Toggleable: disable via Magisk Manager without uninstalling
- Low latency: target < 10 ms added latency
- ARM64 native library (`arm64-v8a`)

---

## 📋 Requirements

| Requirement  | Detail                                    |
| ------------ | ----------------------------------------- |
| Root         | Magisk v26 or later                       |
| Android      | 12 (API 31) minimum; tested on Android 15 |
| Architecture | ARM64 (`arm64-v8a`)                       |
| Storage      | ~4 MB                                     |

---

## 📱 Tested Devices

| Device                         | Android               | ROM   | Result  |
| ------------------------------ | --------------------- | ----- | ------- |
| Samsung Galaxy S25+ (SM-S926B) | Android 15 / One UI 7 | Stock | ✅ Pass |
| ⬛ [Add your device]           | ⬛                    | ⬛    | ⬛      |

_Please report your device in the thread so we can expand this table._

---

## 🖼️ Screenshots

<!-- Upload to Imgur and paste direct .png/.jpg URLs below -->

| Before              | After              |
| ------------------- | ------------------ |
| [screenshot_before] | [screenshot_after] |

_Spectrum analyser screenshot showing 440 Hz reference tone shifted to 432 Hz._

---

## 📦 Downloads

| File                           | Version    | Date   | SHA-256    |
| ------------------------------ | ---------- | ------ | ---------- |
| `audioshift432-v[VERSION].zip` | v[VERSION] | [DATE] | `[SHA256]` |

**[⬛ DOWNLOAD LINK — attach file or paste MediaFire/Mega link here]**

Verify the hash before flashing:

```bash
sha256sum audioshift432-v[VERSION].zip
```

---

## 🔧 Installation

1. Download `audioshift432-v[VERSION].zip`
2. Verify SHA-256 checksum (see Downloads table)
3. Open **Magisk Manager** → Modules → **Install from storage**
4. Select the downloaded zip
5. **Reboot** when prompted
6. Verify: play audio — pitch should be noticeably lower

**To disable:** Magisk Manager → Modules → toggle AudioShift off → reboot.
**To uninstall:** Magisk Manager → Modules → remove AudioShift → reboot.

---

## ⚠️ Known Issues / Limitations

- ⬛ [List any known issues here]
- Calls (VoIP / cellular) may or may not be affected depending on how the carrier audio
  stack is implemented — tested device showed ⬛ [pass / no-effect / partial].
- Bluetooth A2DP: ⬛ [pass / known issue — describe].
- High-bitrate audio (24-bit/96 kHz): ⬛ [pass / known limitation].

---

## 📝 Changelog

### v[VERSION] — [DATE]

- ⬛ [Initial release / changes]

_Full changelog:_ [CHANGELOG.md on GitHub](https://github.com/iamthegreatdestroyer/audioshift/blob/main/CHANGELOG.md)

---

## 🔗 Links

| Resource             | URL                                                                       |
| -------------------- | ------------------------------------------------------------------------- |
| GitHub (source)      | https://github.com/iamthegreatdestroyer/audioshift                        |
| Documentation        | https://iamthegreatdestroyer.github.io/audioshift                         |
| Issues / bug reports | https://github.com/iamthegreatdestroyer/audioshift/issues                 |
| CHANGELOG            | https://github.com/iamthegreatdestroyer/audioshift/blob/main/CHANGELOG.md |

---

## 💬 Support

- Search the thread before posting. Common issues are answered in post #2.
- Include logs when reporting bugs:
  ```bash
  adb logcat -s AudioShift:V | tee audioshift_log.txt
  ```
  Attach `audioshift_log.txt` to your post.
- State your device model, Android version, Magisk version, and ROM name.

---

## 🙏 Credits

- **SoundTouch** audio processing library — Olli Parviainen (LGPL 2.1)
- **Magisk** — topjohnwu
- AudioShift development — [iamthegreatdestroyer](https://github.com/iamthegreatdestroyer)

---

_AudioShift is open-source software released under the MIT License._
_See [LICENSE](https://github.com/iamthegreatdestroyer/audioshift/blob/main/LICENSE) for details._
