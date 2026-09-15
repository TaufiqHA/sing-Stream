# Workspace Rules & Agent Guidelines

## 1. Planning First (Selalu Buat Perencanaan Terlebih Dahulu)
- **Wajib Planning**: Setiap kali menerima prompt atau instruksi dari user, agen **HARUS** membuat rencana kerja (planning) terlebih dahulu sebelum menulis kode, mengubah file, atau mengeksekusi perubahan.
- **Pengecualian (Kecuali Perintah Commit Langsung)**:
  - Jika pengguna secara spesifik menginstruksikan untuk **membuat commit** (contoh: *"buat commit"*, *"commit perubahan ini"*, *"git commit"*), agen **TIDAK PERLU** membuat dokumen planning terlebih dahulu.
  - Agen langsung memeriksa perubahan (`git status`), men-stage file terkait (`git add`), dan membuat commit lokal (`git commit`) dengan pesan yang jelas dan deskriptif.
- **Langkah-langkah Planning**:
  1. **Analisis Masalah & Kebutuhan**: Pahami konteks permintaan user dan telaah file-file terkait di dalam codebase.
  2. **Susun Rencana Kerja**:
     - Jelaskan ringkasan apa yang akan dikerjakan.
     - Cantumkan file yang akan dibuat, diubah, atau dihapus.
     - Rincikan langkah teknis dan alur implementasi secara sistematis.
     - Identifikasi potensi risiko atau edge cases (jika ada).
  3. **Konfirmasi / Presentasi**: Sajikan rencana tersebut kepada user secara jelas dan terstruktur.
  4. **Eksekusi & Verifikasi**: Jalankan perubahan secara bertahap sesuai rencana yang telah ditetapkan dan lakukan verifikasi setelah selesai.
