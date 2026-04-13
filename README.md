
<div align="center">

```
██████╗ ███████╗███████╗ █████╗ ██████╗ ███████╗██╗   ██╗██╗  ██╗
██╔══██╗██╔════╝╚══███╔╝██╔══██╗██╔══██╗██╔════╝██║   ██║╚██╗██╔╝
██████╔╝█████╗    ███╔╝ ███████║██║  ██║█████╗  ██║   ██║ ╚███╔╝ 
██╔══██╗██╔══╝   ███╔╝  ██╔══██║██║  ██║██╔══╝  ╚██╗ ██╔╝ ██╔██╗ 
██║  ██║███████╗███████╗██║  ██║██████╔╝███████╗ ╚████╔╝ ██╔╝ ██╗
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝  ╚═══╝  ╚═╝  ╚═╝
                                              PREMIUM  ·  by rezadevx
```

### Full-Fidelity Roblox Macro Recorder & Playback Engine
*Record everything. Replay perfectly. No limits.*

---

![Open Source](https://img.shields.io/badge/Open%20Source-✓-5865F2?style=for-the-badge&logo=github)
![Luau](https://img.shields.io/badge/Language-Luau-00B4D8?style=for-the-badge)
![Roblox](https://img.shields.io/badge/Platform-Roblox-E8302E?style=for-the-badge&logo=roblox)
![License](https://img.shields.io/badge/License-MIT-27AE60?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-Premium-F2C94C?style=for-the-badge)

</div>

---



**rezadevx premium** adalah macro engine tingkat lanjut yang ditulis dalam **Luau** untuk Roblox. Tidak seperti script macro biasa yang hanya merekam posisi karakter, engine ini merekam *seluruh state* karakter pada setiap frame — animasi, kamera, fisika, klik mouse, tool di tangan, hingga perubahan gravitasi — dan kemudian memutarnya kembali dengan **interpolasi CFrame yang mulus** menggunakan sistem fisika `AlignPosition` dan `AlignOrientation`.

Hasilnya adalah **replay yang tidak bisa dibedakan dari gerakan asli manusia**, bukan sekadar karakter yang berpindah posisi secara kaku.

---

## Fitur Utama

### MacroEngine — Inti dari Segalanya

Seluruh kecerdasan script berpusat di objek `MacroEngine`. Ia mengelola state machine dengan empat kondisi: **Idle → Recording → Playing → Paused**, dan setiap transisi ditangani secara bersih dengan cleanup otomatis.

**Apa yang direkam per frame:**
- `CFrame` lengkap dari `HumanoidRootPart` (12 komponen, posisi + rotasi penuh)
- `CFrame` kamera aktif
- `AssemblyLinearVelocity` dan `AssemblyAngularVelocity` (fisika nyata, bukan hanya posisi)
- Arah gerakan (`MoveDirection`) karakter
- State humanoid (`Jumping`, `Running`, `Freefall`, dll)
- Flag lompat (`Jump`) untuk trigger animasi lompat
- Semua `AnimationTrack` yang aktif beserta `TimePosition`, `Weight`, dan `Speed`-nya
- Tool yang sedang dipegang di tangan
- Status klik mouse kiri (`MouseButton1`)
- `WalkSpeed`, `JumpPower`, dan `workspace.Gravity` saat itu juga

###  Playback Engine — Bukan Sekadar "Move To Position"

Pemutaran ulang menggunakan teknik **frame interpolation** — engine mencari dua frame terdekat (sebelum dan sesudah waktu saat ini), lalu *melakukan lerp* di antaranya. Ini menciptakan gerakan yang halus bahkan pada kecepatan rendah.

Untuk memindahkan karakter, engine *tidak* langsung menulis `HumanoidRootPart.CFrame` (yang akan dilawan oleh physics engine Roblox). Sebaliknya, ia memasang constraint fisika:

```
AlignPosition + AlignOrientation
      ↕                ↕
 MoverAttachment → HumanoidRootPart
```

Attachment "mover" di `workspace.Terrain` digerakkan setiap frame sesuai interpolasi, dan fisika Roblox secara natural menarik karakter mengikutinya — menghasilkan pergerakan yang terasa organik dan bereaksi terhadap dunia.

###  FSM — File System Manager

Setiap macro disimpan sebagai file **JSON** di folder `rezadevxautowalk/` di workspace executor. Data yang disimpan mencakup `Frames` (array rekaman) dan `Dict` (kamus animasi yang mengompres ID aset menjadi angka pendek untuk efisiensi ukuran file).

FSM memeriksa ketersediaan API filesystem executor (`writefile`, `readfile`, `isfile`, dll) secara otomatis — jika tidak tersedia (misalnya di executor yang lebih terbatas), script tetap berjalan namun menonaktifkan fitur simpan/muat.

### GUI — Antarmuka yang Bersih dan Fungsional

GUI dibuat sepenuhnya dengan Roblox Instance API, dengan tema gelap yang konsisten:

| Warna | Fungsi |
|---|---|
| 🔴 `#EB5757` | Tombol RECORD |
| 🟢 `#27AE60` | Tombol PLAY |
| 🟠 `#F2994A` | Tombol PAUSE |
| 🔵 `#2D9CDB` | Tombol RESUME |
| ⚫ `#82828C` | Tombol STOP & SAVE |
| 🔴 `#C0392B` | Tombol DELETE |

Panel kiri berisi kontrol utama, panel kanan menampilkan daftar macro tersimpan yang bisa diklik untuk dimuat langsung. Window bisa di-drag, diminimalkan, dan ditutup.

---

##  Cara Kerja — Alur Teknis

```
[Record] ──► Heartbeat loop merekam state tiap frame
               │
               ▼
         Frames[] disimpan di memori (array Luau)
               │
         [Stop & Save] ─► JSONEncode ─► writefile ke disk
               │
         [Load] ◄── readfile ◄── klik nama file di panel
               │
               ▼
         [Play] ──► Stepped loop berjalan:
                     1. Hitung currentTime += dt × Speed
                     2. Temukan frame pF (sebelum) dan cF (sesudah)
                     3. Hitung alpha = (currentTime - pF.t) / (cF.t - pF.t)
                     4. Lerp CFrame → gerakkan MoverAttachment
                     5. Lerp kamera, velocity, MoveDirection
                     6. Sync animasi, tool, klik mouse, lompat
                     7. Ulangi hingga frame habis atau Stop dipanggil
```

---

##  Cara Menggunakan

**1. Jalankan script** melalui executor Roblox yang mendukung filesystem API (misalnya Synapse X, KRNL, Fluxus, dll).

**2. Panel GUI akan muncul** di tengah layar. Bisa di-drag ke mana saja.

**3. Rekam gerakan:**
   - Tekan **RECORD** untuk mulai merekam
   - Lakukan gerakan, lompat, klik, equip tool — semua akan terekam
   - Tekan **STOP & SAVE**, beri nama file di kotak input kanan, lalu konfirmasi

**4. Putar ulang:**
   - Klik nama file di panel kanan untuk memuat macro
   - Tekan **PLAY** — karakter akan bergerak persis seperti saat direkam
   - Gunakan **-** / **+** untuk mengatur kecepatan putar (0.1× hingga 5.0×)
   - Tekan **PAUSE** untuk jeda, **RESUME** untuk lanjut

**5. Hapus macro:**
   - Pilih file dari daftar
   - Tekan **DELETE SELECTED**

---

## 📁 Struktur File

```
📂 Workspace executor
└── 📂 rezadevxautowalk/
    ├── 📄 NamaMacro.json
    ├── 📄 Combo1.json
    └── 📄 RouteA.json
```

Setiap file JSON berisi:
```json
{
  "Dict": { "rbxassetid://12345": 1, "rbxassetid://67890": 2 },
  "Frames": [
    { "t": 0.0, "cf": [...12 komponen...], "cam": [...], "vel": [...], ... },
    { "t": 0.016, ... }
  ]
}
```

---

## 🛡️ Keamanan & Stabilitas

Script menangani edge case dengan teliti. Jika karakter mati saat recording atau playback, engine secara otomatis berhenti dan membersihkan semua koneksi serta instance. Fungsi `CleanUp()` memastikan tidak ada memory leak — semua `RBXScriptConnection` di-disconnect dan semua `Instance` yang dibuat (attachment, constraint) di-destroy. Stat karakter asli (WalkSpeed, JumpPower, Gravity) selalu dipulihkan setelah playback selesai.

---

##  Lisensi

Script ini dirilis sebagai **open source** di bawah lisensi **MIT**. Bebas digunakan, dimodifikasi, dan didistribusikan dengan menyertakan credit kepada pembuat asli.

```
MIT License — Free to use, modify, and distribute.
Credit to rezadevx is appreciated but not required.
```

---

<div align="center">

##  Credits

```
╔══════════════════════════════════════════════════════╗
║                                                      ║
║           DIBUAT DI PIKIRAN OLEH         ║
║                                                      ║
║   ██████╗ ███████╗███████╗ █████╗ ██████╗ ██╗   ██╗ ║
║   ██╔══██╗██╔════╝╚══███╔╝██╔══██╗██╔══██╗██║   ██║ ║
║   ██████╔╝█████╗    ███╔╝ ███████║██║  ██║██║   ██║ ║
║   ██╔══██╗██╔══╝   ███╔╝  ██╔══██║██║  ██║╚██╗ ██╔╝ ║
║   ██║  ██║███████╗███████╗██║  ██║██████╔╝ ╚████╔╝  ║
║   ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝   ╚═══╝  ║
║                                                      ║
║         Pembuat  ·  Pemikir  ·  Pengeluar Logika     ║
║                                                      ║
║   Setiap baris kode di sini adalah hasil pemikiran   ║
║   mendalam, uji coba tanpa henti, dan dedikasi       ║
║   terhadap kualitas yang tidak mau kompromi.         ║
║                                                      ║
║              "Logic is the art of going wrong        ║
║               with confidence." — but rezadevx       ║
║               goes right, every single time.         ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
```

*Script ini adalah karya open source. Jika kamu menggunakannya, fork-nya,*
*atau belajar darinya — honor the original mind behind it.*

**© rezadevx — All original ideas reserved. Code is free.**

</div>
