# Planning First Rule

Setiap kali menerima prompt atau instruksi baru dari pengguna:
1. **Dilarang langsung melakukan perubahan kode** tanpa membuat planning terlebih dahulu.
2. Buat rencana kerja terstruktur yang mencakup:
   - Pemahaman masalah / kebutuhan.
   - Daftar file target yang terdampak.
   - Langkah demi langkah implementasi teknis.
   - Strategi pengujian atau verifikasi hasil.
3. Tampilkan planning dengan jelas sebelum melanjutkan ke tahap eksekusi.

## Pengecualian
- **Perintah Commit Langsung**: Jika pengguna menginstruksikan untuk membuat commit (`git commit`), agen **TIDAK PERLU** membuat planning terlebih dahulu dan langsung mengeksekusi pembuatan commit secara langsung.
