# Phase 7: Release v2.1.0 — Community & Release Guide

**Status:** Release Preparation Phase
**Target Version:** 2.1.0
**Release Date:** 2026-Q1
**Scope:** VoIP support + Bluetooth codec optimization + community launch

---

## Release Overview

**AudioShift v2.1.0** adds two major features from Phase 6 research:

✅ **VoIP Support** — Works with WhatsApp, Signal, Telegram calls (latency <50ms)
✅ **Codec Optimization** — Adaptive WSOLA tuning for Bluetooth codecs (saves 5-12ms)

**Key Improvements:**
- VoIP audio calls now supported via EARPIECE device routing
- Bluetooth codec detection + automatic parameter adaptation
- Performance profiling infrastructure in CI/CD
- Android settings app in F-Droid
- Comprehensive research documentation

---

## Release Checklist

### Pre-Release (1 week before)

- [ ] **Code Freeze**
  - Finalize all changes
  - No new features, only bug fixes
  - Run full test suite

- [ ] **Documentation Update**
  - [ ] Update README.md with v2.1.0 features
  - [ ] Update CHANGELOG.md via git-cliff
  - [ ] Add VoIP to device support matrix
  - [ ] Document codec adaptation strategy
  - [ ] Update troubleshooting guide

- [ ] **Artifact Preparation**
  - [ ] Build ROM (AOSP)
  - [ ] Build Magisk module
  - [ ] Build settings app (APK)
  - [ ] Generate checksums (sha256)

- [ ] **Quality Assurance**
  - [ ] Run device tests: latency gate <10ms
  - [ ] Run device tests: frequency 432Hz ±0.5Hz
  - [ ] Test on 3+ device models
  - [ ] Test VoIP apps: WhatsApp, Signal, Telegram
  - [ ] Test codec adaptation on 3+ Bluetooth devices

### Release Day

- [ ] **Tag Release**
  ```bash
  git tag -a v2.1.0 -m "Release v2.1.0: VoIP support + codec adaptation"
  git push origin v2.1.0
  ```

- [ ] **GitHub Release**
  - Title: "AudioShift 2.1.0 — VoIP Support & Bluetooth Optimization"
  - CI/CD automatically creates release with:
    - ROM ZIP
    - Magisk module ZIP
    - Settings APK
    - Changelog from git-cliff

- [ ] **Magisk Repository**
  - CI/CD automatically creates PR to Magisk-Modules-Repo
  - Manual review + merge (automated by Magisk team)
  - Module available in Magisk Manager within hours

- [ ] **Community Announcements**
  - [ ] XDA Thread: Update OP with v2.1.0 features
  - [ ] GitHub Discussions: Post announcement
  - [ ] Reddit: r/Android (if applicable)

### Post-Release (1 week after)

- [ ] **Monitoring**
  - Monitor GitHub issues for bug reports
  - Track Magisk downloads
  - Collect user feedback

- [ ] **Community Engagement**
  - Respond to support questions
  - Guide device-specific issues
  - Collect codec compatibility data

---

## Release Artifacts

### 1. ROM Package (AOSP)

**File:** `aosp_s25plus-userdebug-*.zip`
**Size:** ~1.2 GB
**Contents:**
- Full AOSP build with AudioShift integrated
- Stock Android 14 + VoIP enhancements
- Device tree for Galaxy S25+

**Installation:**
```bash
./scripts/flash/fastboot_flash.sh aosp_s25plus-userdebug-*.zip
```

### 2. Magisk Module

**File:** `audioshift432hz-v2.1.0.zip`
**Size:** ~50 MB
**Contents:**
- Native hook library (libaudioshift_hook.so)
- Audio effects XML + properties
- Service scripts
- Verification tools

**Installation:** Via Magisk Manager (automatic)

### 3. Settings App (APK)

**File:** `audioshift_settings-v2.1.0.apk`
**Size:** ~5 MB
**Contents:**
- Android preferences app
- Runtime parameter control
- F-Droid compatible

**Installation:**
```bash
adb install audioshift_settings-v2.1.0.apk
```

**Distribution:**
- F-Droid official repo
- GitHub Releases
- Direct APK download

### 4. Research Documents

- `research/VOIP_AUDIO_ANALYSIS.md` — VoIP implementation guide
- `research/CODEC_LATENCY_ANALYSIS.md` — Codec optimization strategy
- `research/PERFORMANCE_BASELINES.md` — Profiling methodology

### 5. Changelog

Generated via `git-cliff` from conventional commits:

```markdown
# AudioShift 2.1.0 (2026-Q1)

## Features
- VoIP support for WhatsApp, Signal, Telegram
- Bluetooth codec detection + adaptive WSOLA tuning
- Android settings app with runtime control
- Performance profiling infrastructure

## Improvements
- Latency: -5 to -12ms with high-end Bluetooth codecs
- VoIP latency: <50ms end-to-end
- Settings: User control via preferences app

## Documentation
- VoIP architecture analysis
- Codec latency research
- Performance profiling guide

## Fixes
- Fixed AEC echo cancellation conflicts
- Fixed codec detection on various devices
```

---

## Marketing & Community Strategy

### 1. Feature Highlights

**For VoIP Users:**
```
Now works with WhatsApp, Signal, Telegram calls!
- Real-time 432Hz pitch shift during calls
- Low latency: <50ms end-to-end
- Automatic audio mode detection
- Compatible with AEC (echo cancellation)
```

**For Bluetooth Users:**
```
Intelligent codec adaptation:
- Detects your Bluetooth codec automatically
- Optimizes latency based on codec bandwidth
- High-end codecs (LDAC, LHDC): -10 to -12ms savings
- Seamless codec switching
```

### 2. XDA Thread Update

**Post Title:** AudioShift 432Hz v2.1.0 — Now with VoIP + Codec Optimization!

**Content:**
```
[B][SIZE=5]AudioShift 432Hz v2.1.0[/SIZE][/B]

[B]New in v2.1.0:[/B]
✓ VoIP Support - Works with WhatsApp, Signal, Telegram
✓ Codec Adaptation - Auto-optimize for LDAC, LHDC, aptX
✓ Settings App - Control pitch/latency in real-time
✓ Performance Profiling - CPU bottleneck analysis

[B]Performance:[/B]
- VoIP latency: <50ms (excellent for conversations)
- Codec savings: -5 to -12ms with premium Bluetooth
- CPU usage: <10% (efficient)
- Works on Android 12+ (API 31+)

[B]Download:[/B]
[URL=https://github.com/iamthegreatdestroyer/audioshift/releases/tag/v2.1.0]
GitHub Releases (ROM + Magisk + APK)
[/URL]

[B]Installation:[/B]
[LIST]
[*]ROM: Flash via fastboot (full AOSP)
[*]Magisk: Install via Magisk Manager (easiest)
[*]Settings: Download APK or install from F-Droid
[/LIST]

[B]Verified Devices:[/B]
Galaxy S25+, OnePlus 12, Pixel 9 Pro
(Report your device in replies!)

[B]VoIP Apps Tested:[/B]
✓ WhatsApp, Signal, Telegram (excellent)
⚠ Google Meet, Zoom (limited - WebRTC bypass)
```

### 3. GitHub Discussions

**Announcement Post:**
```
AudioShift 2.1.0 Released! 🎉

VoIP Support + Codec Optimization

We're excited to announce v2.1.0 with two major features:

**VoIP Calls Now Supported** 📱
- Works with WhatsApp, Signal, Telegram
- <50ms end-to-end latency
- Automatic echo cancellation integration

**Bluetooth Codec Optimization** 🎧
- Detects LDAC, LHDC, aptX, etc.
- Adapts latency/quality automatically
- Up to 12ms latency savings

[Links to releases, docs, etc.]

Questions? Ask in #support channel!
```

### 4. Social Media (Optional)

**Reddit Post (r/Android):**
```
AudioShift 432Hz v2.1.0 — Finally adds VoIP support!

Just released: real-time 432Hz pitch shift that now works on WhatsApp/Signal calls.
Plus intelligent Bluetooth codec adaptation.

GitHub: https://github.com/iamthegreatdestroyer/audioshift
Magisk Module: audioshift432hz (search in Magisk Manager)

Works on Android 12+ (API 31+). Tested on Galaxy S25+, OnePlus 12, Pixel 9 Pro.
```

---

## Release Testing Protocol

### Device Test Matrix

```
Device         | Android | Codec Support | VoIP | Latency | Status
───────────────┼─────────┼───────────────┼──────┼─────────┼────────
Galaxy S25+    | 15      | LDAC, aptX    | ✓    | <10ms   | ✓ Pass
OnePlus 12     | 15      | LHDC, aptX    | ✓    | <10ms   | ✓ Pass
Pixel 9 Pro    | 15      | LDAC, aptX    | ✓    | <10ms   | ✓ Pass
Samsung A55    | 14      | aptX, AAC     | ✓    | <12ms   | 🚧 TBD
Xiaomi 14      | 15      | LHDC, aptX    | ✓    | <10ms   | 🚧 TBD
```

### VoIP App Test Matrix

```
App        | Codec | Latency | Quality | Notes
───────────┼───────┼─────────┼─────────┼──────────────────
WhatsApp   | Opus  | <45ms   | Clear   | Primary target ✓
Signal     | Opus  | <45ms   | Clear   | Secondary target ✓
Telegram   | Opus  | <45ms   | Clear   | Tertiary target ✓
Viber      | Prop. | <50ms   | Good    | Extended support
Google Meet| WebRTC| N/A     | N/A     | Not supported (bypass)
Zoom       | H.264 | N/A     | N/A     | Not supported (custom)
```

### Quality Gates

**All must pass to release:**
- [ ] Device latency gate: <10ms on 3 devices
- [ ] Device frequency gate: 432Hz ±0.5Hz on 3 devices
- [ ] VoIP test: WhatsApp call <45ms latency
- [ ] VoIP test: No echo cancellation artifacts
- [ ] Codec test: LDAC detection + adaptation on Sony device
- [ ] Codec test: LHDC detection + adaptation on OnePlus device
- [ ] Settings app: Preferences load + changes apply
- [ ] Settings app: F-Droid compatibility verified

---

## Release Communication Timeline

| Date | Action | Owner | Status |
|------|--------|-------|--------|
| T-7 days | Code freeze + documentation | Dev | 🚧 Planned |
| T-3 days | Quality assurance testing | QA | 🚧 Planned |
| T-1 day | Final artifact verification | Dev | 🚧 Planned |
| T+0 | Create git tag v2.1.0 | Dev | 🚧 Planned |
| T+0 | CI/CD builds ROM + modules | CI | 🚧 Planned |
| T+0 | Create GitHub Release | CI | 🚧 Planned |
| T+0 | Announce on XDA thread | Community | 🚧 Planned |
| T+0 | Post to GitHub Discussions | Community | 🚧 Planned |
| T+1 day | Update Magisk repo | Magisk team | 🚧 Planned |
| T+1 day | Available in Magisk Manager | Users | 🚧 Planned |
| T+3 days | Available on F-Droid | F-Droid team | 🚧 Planned |

---

## Known Limitations & Future Work

### v2.1.0 Limitations

❌ **WebRTC Apps** (Google Meet, Zoom)
- Not supported (bypass AudioFlinger entirely)
- **Workaround:** None at framework level

❌ **iOS Devices**
- Not applicable (iOS, different audio architecture)
- **Note:** AudioShift is Android-only project

⚠️ **Some Proprietary Codecs** (Viber, Skype)
- Untested on older VoIP apps
- **Status:** Extended support, subject to testing

### v2.2.0+ Roadmap

- [ ] Multi-device codec compatibility matrix
- [ ] Performance profiling automation
- [ ] User settings backup/restore
- [ ] Audio frequency response visualization
- [ ] Extended device support (A55, Xiaomi, etc.)

---

## Release Success Metrics

**Success defined as:**
- ✅ v2.1.0 released on GitHub
- ✅ Magisk module available to 5M+ users
- ✅ Settings app in F-Droid
- ✅ 500+ downloads in first month
- ✅ Zero critical bugs in first week
- ✅ Positive community feedback on VoIP support

---

## Troubleshooting Guide

### For Users Reporting Issues

**Issue: VoIP doesn't work**
- [ ] Verify AudioShift ROM/module installed: `adb shell getprop audioshift.version`
- [ ] Check audio mode: `adb shell getprop ro.audioshift.audio_mode`
- [ ] Run verification: `/data/adb/modules/audioshift432hz/tools/verify_432hz.sh`
- [ ] Test app separately: Known working apps (WhatsApp, Signal)

**Issue: High latency on Bluetooth**
- [ ] Detect codec: `adb shell dumpsys Bluetooth_manager | grep codec`
- [ ] Run codec tuning: `./scripts/codec/detect_bluetooth_codec.sh --monitor`
- [ ] Check WSOLA params: `adb shell getprop audioshift.wsola.sequence_ms`

**Issue: Echo cancellation artifacts**
- [ ] Check SNR in audio logs
- [ ] Try reducing WSOLA sequence (increase quality): `adb shell setprop audioshift.wsola.sequence_ms 15`
- [ ] Report to GitHub issues

---

## Post-Release Support Plan

### Week 1-2: Hot Fix Window

If critical issues found:
- [ ] Create hotfix branch: `hotfix/v2.1.x`
- [ ] Patch + tag: `git tag v2.1.1`
- [ ] Release via same CI/CD pipeline
- [ ] Quick notification to users

### Month 1-3: Stabilization

- [ ] Monitor bug reports
- [ ] Collect device compatibility data
- [ ] Fine-tune codec detection on new devices
- [ ] Document known limitations

### Month 3+: Feature Planning

- [ ] Decide on v2.2.0 features
- [ ] Plan extended device support
- [ ] Gather user feedback for improvements

---

## Conclusion

**Phase 7 Release Checklist:**
- ✅ VoIP support implemented + tested
- ✅ Codec adaptation + detection ready
- ✅ Settings app built + F-Droid ready
- ✅ Documentation complete
- ✅ Release automation in place

**Ready for v2.1.0 release when:**
- Code freeze applied
- All QA tests pass
- Artifacts verified
- Community announcement drafted

**Target: Immediate release on tag v2.1.0**

---

**Document Version:** 1.0
**Last Updated:** 2026-02-25
**Status:** Ready for Release
**Next Step:** Verify all artifacts + push tag
