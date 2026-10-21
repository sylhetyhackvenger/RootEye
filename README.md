
<div align="center">

# 🛡️ RootEye

### View Element eXtractor — Android Deep Device Monitor

**A root-powered, terminal-only reconnaissance tool for Android.**  
No files. No logs. No traces. Just pure, real-time visibility into what your device is doing — right now.

[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Termux-brightgreen?style=flat-square)](https://termux.dev)
[![Shell](https://img.shields.io/badge/shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Root](https://img.shields.io/badge/requires-root-red?style=flat-square)](#-requirements)
[![No Files](https://img.shields.io/badge/storage-zero%20files-blue?style=flat-square)](#-privacy--operational-security)
[![License](https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square)](#-license)

**Author:** [SYLHETYHACKVENGER (THE-ERROR808)](#-author)

</div>

---

## 📖 Overview

**RootEye** is a professional-grade, single-script Android monitoring tool built for **security researchers, penetration testers, reverse engineers, and power users** who need real-time, on-device intelligence without leaving artifacts behind.

Running entirely inside **Termux with root**, RootEye pulls live state directly from Android's own diagnostic subsystems — `dumpsys`, `uiautomator`, `logcat`, `ss`, `ip`, `/proc` — and renders it in a clean, color-coded terminal dashboard.

> **Core philosophy:** *Observe everything. Store nothing.*

---

## ✨ Features

| Category | Capability |
|---|---|
| 🎯 **Foreground App Tracking** | Live package name, activity, and window focus |
| 🧠 **Session App History** | In-memory timeline of app switches (RAM-only, wiped on exit) |
| 🖼️ **UI Element Extraction** | On-screen text, accessibility labels, clickable nodes, input fields, scrollable containers via `uiautomator` |
| 🔔 **Notification Interception** | Active notification records, packages, titles, ticker text |
| 📋 **Clipboard Inspection** | Current clipboard contents (root) |
| 🌐 **Network Recon** | Live TCP connections with owning PIDs + all interface addresses |
| 🔋 **System Telemetry** | Battery state, top CPU consumers, memory breakdown |
| 📜 **Event Timeline** | Snapshot of `ActivityManager` / `WindowManager` logcat events |
| 🧹 **Zero-Footprint** | Temp UI dump deleted instantly after read + on exit trap |
| 🎨 **Clean UI** | ANSI-colored, structured, human-readable dashboard |

---

## 🔐 Privacy & Operational Security

RootEye was designed for **forensic and field use where leaving traces is unacceptable**.

### What RootEye does **NOT** do
- ❌ Writes no log files
- ❌ Creates no config files
- ❌ Stores no history on disk
- ❌ Sends no data over the network
- ❌ Persists no data after exit

### Temporary artifacts
| Artifact | Location | Lifetime |
|---|---|---|
| UI hierarchy dump | `/sdcard/ui_dump.xml` | Deleted immediately after read + on `INT`/`TERM` |

> **Note:** System-level buffers (e.g. `logcat` ring buffer, system clipboard) are managed by Android itself and are unaffected by RootEye's read-only access.

---

## ⚙️ Requirements

- ✅ **Rooted Android device** (Magisk, KernelSU, or equivalent)
- ✅ **Termux** installed ([F-Droid version recommended](https://f-droid.org/en/packages/com.termux/))
- ✅ Root granted to Termux
- ✅ Android 8.0+ (tested against modern AOSP-based ROMs)

---

## 🚀 Installation

### 1. Clone or download

```bash
git clone https://github.com/sylhetyhackvenger/RootEye
cd RootEye
chmod +x rooteye.sh
```

2. One-time dependency setup

```bash
bash rooteye.sh --setup
```

This installs:

· tsu — root shell wrapper
· procps — process utilities
· iproute2 — networking (ip, ss)
· net-tools — legacy network tools

3. Grant root to Termux

```bash
su -c "id"
# Expected: uid=0(root) ...
```

---

🎮 Usage

```bash
bash rooteye.sh
```

Workflow:

1. Launch the tool → banner + root check runs automatically.
2. Press ENTER to begin.
3. Switch to any app you want to inspect.
4. Return to Termux and press ENTER → full snapshot is rendered.
5. Press ENTER again to re-scan, or Ctrl+C to exit cleanly.

Nothing you see is written to disk. When Termux closes, it's gone.

---

🖥️ What You'll See

```
▌ FOREGROUND APP
─────────────────────────────────────────────────────────────
  ➜ Package : com.example.target
  ➜ Activity: com.example.target.MainActivity
  Window focus:
    mCurrentFocus=Window{... com.example.target/...MainActivity}

▌ UI ELEMENTS — WHAT'S ON SCREEN RIGHT NOW
─────────────────────────────────────────────────────────────
  Text on screen:
    · Login
    · Email address
    · Password
    · Sign in
  Accessibility labels:
    · Submit button
  Clickable buttons / links:
    · Sign in
    · Forgot password
  Input fields:
    · [hint] Enter your email
    · [hint] Enter your password

▌ ACTIVE NOTIFICATIONS
▌ CLIPBOARD
▌ NETWORK ACTIVITY
▌ SYSTEM — BATTERY · CPU · MEMORY
▌ SYSTEM EVENTS (logcat snapshot)
```

---

🧩 Use Cases

· 🔍 Penetration testing — verify what a target app leaks to the UI hierarchy or accessibility tree.
· 🧪 Reverse engineering — map screens, identifiers, and input flows without a GUI tool.
· 📱 Malware analysis — observe suspicious package behavior, network calls, and notifications live.
· 🛠️ App QA & accessibility audits — inspect content-desc coverage, input hints, and scroll containers.
· 🕵️ Field forensics — collect real-time state on a compromised or test device with zero disk artifacts.

---

🧠 Architecture

```
┌───────────────────────────────────────────────┐
│                Termux (Bash)                  │
├───────────────────────────────────────────────┤
│  main loop                                    │
│    ├── get_fg_app / get_fg_activity           │
│    ├── get_stack_history                      │
│    ├── dump_ui ──► uiautomator ──► parse_ui   │
│    ├── get_notifications   (dumpsys)          │
│    ├── get_clipboard       (dumpsys)          │
│    ├── get_network         (ss / ip)          │
│    ├── get_system          (battery/top/proc) │
│    └── get_logcat_snap     (logcat -d)        │
│                                               │
│  cleanup trap ──► rm /sdcard/ui_dump.xml      │
└───────────────────────────────────────────────┘
              │
              ▼
        su -c "…"  (root bridge)
```

Every subsystem call is wrapped through su -c, granting read-only access to privileged Android diagnostics — nothing more.

---

🧹 Cleanup Guarantee

RootEye installs a trap on INT and TERM:

```bash
trap cleanup INT TERM
cleanup() {
    su -c "rm -f $UI_DUMP 2>/dev/null"
    exit 0
}
```

Press Ctrl+C at any point — the temp dump is removed and the session terminates with confirmation:

```
[!] Monitor stopped. Nothing was saved.
```

---

⚠️ Disclaimer

RootEye is intended strictly for lawful security research, authorized penetration testing, and personal device auditing.

Running this tool against devices you do not own or have explicit written permission to test is illegal in most jurisdictions and violates the privacy of others.

The author assumes no liability for misuse, damage, or legal consequences arising from this software. You are solely responsible for how you use it.

Root access is inherently powerful — treat it accordingly.

---

🧾 Author

SYLHETYHACKVENGER — aka THE-ERROR808

Security researcher · Offensive tooling · Android internals

Built for the operator who prefers a black screen, a blinking cursor, and zero footprint.

---

📄 License

This project is licensed under the MIT License — see LICENSE for details.

---

<div align="center">

⭐ If RootEye helped your research, star the repo.

Observe everything. Store nothing.

</div>
```
