<p align="center">
  <img src="assets/hero.gif" width="100%">
</p>

<h1 align="center">⚙️ Kali NetHunter – Kernel & Installer Package</h1>

<p align="center">
  <b>Advanced Android Security Environment</b><br>
  <i>Kernel • AnyKernel3 • BusyBox • NetHunter</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android-red">
  <img src="https://img.shields.io/badge/Level-Advanced-orange">
  <img src="https://img.shields.io/badge/Language-Shell-green">
  <img src="https://img.shields.io/badge/Status-Experimental-yellow">
</p>

---

## 🚨 READ THIS FIRST

<p align="center">
  <img src="assets/warning.gif" width="70%">
</p>

⚠️ **This repository contains low-level Android system files.**  
It is **not** a normal app or script.

Improper usage can:
- Brick devices
- Break boot images
- Cause data loss

Proceed **only if you understand Android kernel flashing**.

---

## 📌 What Is This Repository?

<p align="center">
  <img src="assets/overview.gif" width="75%">
</p>

This repository contains files used for setting up **Kali NetHunter** on **rooted Android devices**, including:

- Kernel flashing scripts  
- Boot image patching tools  
- BusyBox binaries  
- Supporting shell utilities  

It is intended for **security research and experimentation**, not casual use.

---

## 🧠 Intended Audience

<p align="center">
  <img src="assets/audience.gif" width="65%">
</p>

This project is for users who are familiar with:

- Android rooting
- Custom recovery (TWRP)
- Boot images & kernels
- Magisk / AnyKernel3
- Linux command-line tools

If you don’t know what those are, **this repo is not for you**.

---

## 🧩 High-Level Architecture

<p align="center">
  <img src="assets/architecture.svg" width="85%">
</p>

---

## 📂 Repository Structure

<p align="center">
  <img src="assets/structure.gif" width="70%">
</p>

Kali-nethunter/ │ ├── anykernel.sh          # Kernel flashing logic ├── ak3-core.sh           # AnyKernel3 core ├── busybox*              # BusyBox binaries ├── magiskboot            # Boot image patching tool ├── patch.d/              # Kernel patch scripts ├── zImage                # Kernel image ├── NetHunter.apk         # Android application └── README.md

---

## 🛠️ Key Components Explained

<p align="center">
  <img src="assets/components.gif" width="75%">
</p>

- **AnyKernel3** – Flashing framework without touching recovery  
- **BusyBox** – Unix utilities for Android  
- **MagiskBoot** – Boot image unpack/patch/repack  
- **zImage** – Linux kernel binary  
- **Shell scripts** – Glue logic for automation  

---

## ⚠️ Safety Notes

<p align="center">
  <img src="assets/safety.gif" width="65%">
</p>

- Always take a **full backup** before flashing  
- Use only on **supported devices**  
- Do not flash random kernels  
- This repository is **experimental**

---

## 🧪 Use Cases

<p align="center">
  <img src="assets/usecases.gif" width="70%">
</p>

- Android security research  
- Learning kernel flashing workflows  
- NetHunter environment setup  
- Academic exploration of mobile security  

---

## 🚫 Disclaimer

<p align="center">
  <img src="assets/disclaimer.gif" width="60%">
</p>

This repository is provided **as-is**.

The author is **not responsible** for:
- Device damage
- Data loss
- Misuse of the files

Use at your own risk.

---

## 📜 License

Refer to the included `LICENSE` file.

---

<p align="center">
  © 2025. Educational & experimental use only.
</p>
