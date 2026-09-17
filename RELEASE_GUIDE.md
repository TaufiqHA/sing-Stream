# Panduan Rilis Aplikasi (Release Guide)
**Melindastore Youtube Stream Karaoke** (`com.singstream.app`)

Dokumen ini berisi panduan teknis lengkap untuk mempersiapkan, menandatangani (*signing*), dan membangun (*build*) aplikasi untuk rilis produksi (Google Play Store atau instalasi langsung/APK mandiri).

---

## 1. Persiapan Keystore Rilis (App Signing)

Untuk mendistribusikan aplikasi secara publik atau mengunggahnya ke Google Play Store, Anda perlu menandatangani aplikasi dengan keystore resmi.

### Langkah 1: Generate Keystore Baru (Hanya Sekali)
Buka terminal (Command Prompt / PowerShell) dan jalankan perintah berikut:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Anda akan diminta memasukkan kata sandi (*keystore password* dan *key password*).
- Masukkan identitas pengembang (nama, organisasi, kota, dll).
- File keystore akan tersimpan di folder `android/upload-keystore.jks`.

> [!CAUTION]
> **SIMPAN KEYSTORE DENGAN AMAN!**
> Jangan pernah menghapus atau kehilangan file `upload-keystore.jks` dan kata sandinya. Jika hilang, Anda tidak akan bisa merilis pembaruan (*update*) untuk aplikasi yang sama di Google Play Store. Keystore ini sudah otomatis diabaikan oleh `.gitignore` sehingga tidak akan terunggah ke repositori Git.

---

### Langkah 2: Buat File `android/key.properties`
1. Salin template `android/key.properties.example` menjadi `android/key.properties`:
   ```powershell
   Copy-Item android/key.properties.example android/key.properties
   ```
2. Buka `android/key.properties` dan isi dengan konfigurasi Anda:
   ```properties
   keyAlias=upload
   keyPassword=PASSWORD_KEY_ANDA
   storePassword=PASSWORD_KEYSTORE_ANDA
   storeFile=../upload-keystore.jks
   ```

*Catatan: Jika file `android/key.properties` tidak ada, build release akan otomatis menggunakan debug keystore sebagai fallback (berguna untuk testing release lokal).*

---

## 2. Update Versi Aplikasi

Setiap kali ingin merilis versi baru, perbarui file [pubspec.yaml](file:///d:/TAUFIQ%20PUNYA/sing-Stream/pubspec.yaml):

```yaml
version: 1.0.0+1
```

Format penomoran:
- **`1.0.0`** (`versionName`): Nomor versi yang dilihat oleh pengguna di Play Store / aplikasi.
- **`1`** (`versionCode`): Nomor integer yang wajib dinaikkan setiap kali upload build baru ke Google Play Console (misal `1.0.1+2`, `1.0.2+3`, dst).

---

## 3. Perintah Build Rilis

Jalankan perintah berikut di root folder proyek:

### Opsi A: Build Android App Bundle (AAB) - **Direkomendasikan untuk Google Play**
Format `.aab` memisahkan resource untuk setiap perangkat pengguna sehingga ukuran unduhan aplikasi menjadi jauh lebih kecil.

```bash
flutter build appbundle --release
```
- **Lokasi Output**:
  `build/app/outputs/bundle/release/app-release.aab`

---

### Opsi B: Build APK Universal (Untuk Distribusi Mandiri / Sideloading)
APK tunggal yang dapat dipasang langsung pada perangkat Android apa pun:

```bash
flutter build apk --release
```
- **Lokasi Output**:
  `build/app/outputs/flutter-apk/app-release.apk`

---

### Opsi C: Build APK Split per-ABI (Ukuran File Lebih Ramping)
Menghasilkan APK terpisah untuk arsitektur CPU spesifik (`arm64-v8a`, `armeabi-v7a`, `x86_64`):

```bash
flutter build apk --release --split-per-abi
```
- **Lokasi Output**:
  - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
  - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
  - `build/app/outputs/flutter-apk/app-x86_64-release.apk`

---

## 4. Keamanan & Konfigurasi Ekstra

- **ProGuard / R8**: Sudah dikonfigurasi di `android/app/proguard-rules.pro` untuk menjaga kelancaran Google Play Services Cast, WebView, dan YouTube Player.
- **Cleartext Traffic**: Diaktifkan di `AndroidManifest.xml` (`android:usesCleartextTraffic="true"`) agar aplikasi dapat berkomunikasi dengan endpoint backend HTTP (`http://tomsikaraoke.xyz`).
- **Permissions**: Izin internet, WiFi state, Google Cast, dan media gallery sudah terdaftar dengan benar di `android/app/src/main/AndroidManifest.xml`.
