import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaoke_app/main.dart';
import 'package:karaoke_app/screens/admin/admin_home_screen.dart';
import 'package:karaoke_app/screens/admin/category/admin_category_screen.dart';
import 'package:karaoke_app/screens/admin/song/admin_song_screen.dart';
import 'package:karaoke_app/screens/admin/user/admin_user_screen.dart';
import 'package:karaoke_app/models/user_model.dart';
import 'package:karaoke_app/screens/home_screen.dart';
import 'package:karaoke_app/screens/login_screen.dart';
import 'package:karaoke_app/screens/profile/profile_screen.dart';
import 'package:karaoke_app/screens/admin/setting/admin_setting_screen.dart';
import 'package:karaoke_app/core/services/dummy_admin_service.dart';
import 'package:karaoke_app/core/services/dummy_application_service.dart';
import 'package:karaoke_app/core/services/dummy_auth_service.dart';
import 'package:karaoke_app/core/services/dummy_category_service.dart';
import 'package:karaoke_app/core/services/dummy_song_service.dart';
import 'package:karaoke_app/core/services/dummy_user_service.dart';
import 'package:karaoke_app/core/services/storage_service.dart';
import 'package:karaoke_app/screens/splash_screen.dart';
import 'package:karaoke_app/screens/user/user_main_layout.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splash screen renders properly and transitions to UserMainLayout', (WidgetTester tester) async {
    await tester.pumpWidget(const KaraokeApp());

    // Memverifikasi Splash Screen tampil dengan teks 'Sing Stream'
    expect(find.text('Sing Stream'), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Animasi pump
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sing Your Heart Out'), findsOneWidget);

    // Advance timer splash screen (2.5s) dan animasi transisi (0.6s)
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    // Verifikasi otomatis berpindah ke UserMainLayout
    expect(find.byType(UserMainLayout), findsOneWidget);
  });

  testWidgets('Login screen validation smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Memverifikasi field Username & Password tersedia
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);

    // Memverifikasi TIDAK ADA lupa password atau register
    expect(find.textContaining('Lupa'), findsNothing);
    expect(find.textContaining('Daftar'), findsNothing);
    expect(find.textContaining('Register'), findsNothing);

    // Mencoba submit saat field kosong
    await tester.tap(find.text('Masuk'));
    await tester.pump();

    // Verifikasi pesan validasi muncul
    expect(find.text('Username tidak boleh kosong'), findsOneWidget);
    expect(find.text('Password tidak boleh kosong'), findsOneWidget);
  });

  testWidgets('Admin Home Screen renders summary of songs and users', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminHomeScreen(adminService: DummyAdminService()),
        ),
      ),
    );

    // Loading state awal
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pump untuk menyelesaikan request dummy stats
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Verifikasi judul dan kartu ringkasan
    expect(find.text('Beranda Admin'), findsOneWidget);
    expect(find.text('Total Lagu Diinput'), findsOneWidget);
    expect(find.text('Total User Terdaftar'), findsOneWidget);
    expect(find.text('1.250'), findsOneWidget);
  });

  testWidgets('Admin Category Screen CRUD operations test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminCategoryScreen(categoryService: DummyCategoryService()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. READ: Memverifikasi kategori bawaan tampil
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Pop Indonesia'), findsOneWidget);
    expect(find.text('Dangdut & Koplo'), findsOneWidget);

    // 2. CREATE: Menambah kategori baru 'Jazz & Blues' via tombol Tambah
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Kategori'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, ''), 'Jazz & Blues');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Verifikasi kategori baru muncul
    expect(find.text('Jazz & Blues'), findsOneWidget);

    // 3. UPDATE: Mengubah kategori 'Jazz & Blues' menjadi 'Smooth Jazz'
    final editButtons = find.byTooltip('Ubah');
    await tester.tap(editButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Ubah Kategori'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Smooth Jazz');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Smooth Jazz'), findsOneWidget);

    // 4. DELETE: Menghapus kategori 'Smooth Jazz'
    final deleteButtons = find.byTooltip('Hapus');
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Hapus Kategori'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
    await tester.pumpAndSettle();

    // Verifikasi 'Smooth Jazz' sudah terhapus
    expect(find.text('Smooth Jazz'), findsNothing);
  });

  testWidgets('Admin Song Screen CRUD and search/filter test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSongScreen(
            songService: DummySongService(),
            categoryService: DummyCategoryService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. READ: Memverifikasi lagu awal dan header tampil
    expect(find.text('Kelola Lagu'), findsOneWidget);
    expect(find.text('Sial'), findsOneWidget);
    expect(find.text('Mahalini'), findsOneWidget);
    expect(find.text('Rungkad'), findsOneWidget);
    expect(find.text('Nada: Wanita'), findsWidgets);

    // 2. SEARCH: Mencari berdasarkan judul lagu 'Sial'
    await tester.enterText(find.byType(TextField), 'Sial');
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Sial'), findsOneWidget);
    expect(find.text('Rungkad'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Rungkad'), findsOneWidget);

    // 3. CREATE: Menambahkan lagu baru
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Lagu'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Lagu Baru'), findsOneWidget);

    final formFields = find.byType(TextFormField);
    // formFields[0]: Judul Lagu
    // formFields[1]: Penyanyi
    // formFields[2]: URL Lagu
    // formFields[3]: Durasi
    await tester.enterText(formFields.at(0), 'Hampa');
    await tester.enterText(formFields.at(1), 'Ari Lasso');
    await tester.enterText(formFields.at(2), 'https://example.com/audio/hampa.mp3');
    await tester.enterText(formFields.at(3), '04:12');

    // Pilih Nada 'Pria' dari dropdown
    final nadaDropdown = find.byKey(const Key('nada_dropdown'));
    await tester.tap(nadaDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nada Pria').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Verifikasi lagu baru muncul di list
    expect(find.text('Hampa'), findsOneWidget);
    expect(find.text('Ari Lasso'), findsOneWidget);
    expect(find.text('04:12'), findsOneWidget);

    // 4. UPDATE: Mengubah lagu 'Hampa'
    final editButtons = find.byTooltip('Ubah');
    await tester.tap(editButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Ubah Lagu'), findsOneWidget);
    final editFields = find.byType(TextFormField);
    await tester.enterText(editFields.at(0), 'Hampa (Akustik)');

    // Ubah Nada menjadi 'Wanita' dari dropdown
    await tester.tap(find.byKey(const Key('nada_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nada Wanita').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Hampa (Akustik)'), findsOneWidget);

    // 5. DELETE: Menghapus lagu 'Hampa (Akustik)'
    final deleteButtons = find.byTooltip('Hapus');
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Hapus Lagu'), findsOneWidget);
    expect(find.textContaining('Apakah Anda yakin ingin menghapus lagu "Hampa (Akustik)"'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
    await tester.pumpAndSettle();

    // Verifikasi lagu terhapus
    expect(find.text('Hampa (Akustik)'), findsNothing);
  });

  testWidgets('Admin User Screen CRUD and search/filter test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminUserScreen(userService: DummyUserService()),
      ),
    );
    await tester.pumpAndSettle();

    // 1. READ: Memverifikasi user awal tampil
    expect(find.text('Kelola User'), findsOneWidget);
    expect(find.text('admin'), findsWidgets);
    expect(find.text('operator'), findsOneWidget);
    expect(find.text('karaoke_lover'), findsOneWidget);

    // 2. FILTER & SEARCH: Mencari berdasarkan username 'karaoke_lover'
    await tester.enterText(find.byType(TextField), 'karaoke_lover');
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'karaoke_lover'), findsOneWidget);
    expect(find.text('operator'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('operator'), findsOneWidget);

    // Filter by role chip 'Admin'
    await tester.tap(find.widgetWithText(ChoiceChip, 'Admin'));
    await tester.pumpAndSettle();
    expect(find.text('admin'), findsWidgets);
    expect(find.text('operator'), findsOneWidget);
    expect(find.text('karaoke_lover'), findsNothing);

    // Reset filter to 'Semua'
    await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
    await tester.pumpAndSettle();
    expect(find.text('karaoke_lover'), findsOneWidget);

    // 3. CREATE: Menambahkan user baru
    await tester.tap(find.text('Tambah User'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Pengguna Baru'), findsOneWidget);

    final formFields = find.byType(TextFormField);
    // formFields[0]: Username
    // formFields[1]: Password
    await tester.enterText(formFields.at(0), 'budi_santoso');
    await tester.enterText(formFields.at(1), 'budi1234');

    // Pilih role 'Administrator'
    await tester.tap(find.text('Administrator'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan Pengguna'));
    await tester.pumpAndSettle();

    // Verifikasi user baru muncul di list
    expect(find.text('budi_santoso'), findsOneWidget);

    // 4. UPDATE: Mengubah user 'budi_santoso'
    final editButtons = find.byTooltip('Ubah');
    await tester.tap(editButtons.last);
    await tester.pumpAndSettle();

    expect(find.text('Ubah Akun Pengguna'), findsOneWidget);
    final editFields = find.byType(TextFormField);
    await tester.enterText(editFields.at(0), 'budi_super');

    // Ubah role ke 'User Biasa'
    await tester.tap(find.text('User Biasa'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(find.text('budi_super'), findsOneWidget);

    // 5. DELETE: Menghapus user 'budi_super'
    final deleteButtons = find.byTooltip('Hapus');
    await tester.tap(deleteButtons.last);
    await tester.pumpAndSettle();

    expect(find.text('Hapus Pengguna'), findsOneWidget);
    expect(find.textContaining('Apakah Anda yakin ingin menghapus akun pengguna "budi_super"'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
    await tester.pumpAndSettle();

    // Verifikasi user terhapus
    expect(find.text('budi_super'), findsNothing);
  });

  testWidgets('Profile Screen renders user information and tabs correctly', (WidgetTester tester) async {
    const testUser = UserModel(
      id: 'usr_test_1',
      username: 'karaoke_lover',
      displayName: 'Karaoke King',
      email: 'karaoke@sing.com',
      role: 'user',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(initialUser: testUser),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi judul dan data user di header
    expect(find.text('Manajemen Profil'), findsOneWidget);
    expect(find.text('Karaoke King'), findsWidgets);
    expect(find.text('@karaoke_lover'), findsOneWidget);
    expect(find.text('MEMBER KARAOKE'), findsOneWidget);

    // Verifikasi tab navigasi muncul (hanya Data Pribadi dan Keamanan)
    expect(find.text('Data Pribadi'), findsOneWidget);
    expect(find.text('Keamanan'), findsOneWidget);
    expect(find.text('Preferensi'), findsNothing);

    // Tab Data Pribadi aktif secara default
    expect(find.text('Informasi Akun'), findsOneWidget);
    expect(find.text('Nama Lengkap / Tampilan'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
  });

  testWidgets('Profile Screen updates display name and email', (WidgetTester tester) async {
    const testUser = UserModel(
      id: 'usr_test_2',
      username: 'budi_singer',
      displayName: 'Budi Lama',
      email: 'budi@old.com',
      role: 'user',
    );

    final storage = await StorageService.getInstance();
    await storage.saveToken('test_token');
    final authService = DummyAuthService(storageService: storage);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(initialUser: testUser, authService: authService),
      ),
    );
    await tester.pumpAndSettle();

    // Edit nama tampilan
    final displayNameFinder = find.widgetWithText(TextFormField, 'Budi Lama');
    await tester.enterText(displayNameFinder, 'Budi Suara Emas');

    // Edit email
    final emailFinder = find.widgetWithText(TextFormField, 'budi@old.com');
    await tester.enterText(emailFinder, 'budi@emas.com');

    // Tap Simpan
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    // Verifikasi notifikasi berhasil dan nama di header berubah
    expect(find.text('Profil berhasil diperbarui!'), findsOneWidget);
    expect(find.text('Budi Suara Emas'), findsWidgets);
  });

  testWidgets('Profile Screen change password validation and process', (WidgetTester tester) async {
    const testUser = UserModel(
      id: 'usr_test_3',
      username: 'admin',
      displayName: 'Admin Karaoke',
      role: 'admin',
    );

    final storage = await StorageService.getInstance();
    await storage.saveToken('test_token');
    final authService = DummyAuthService(storageService: storage);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(initialUser: testUser, authService: authService),
      ),
    );
    await tester.pumpAndSettle();

    // Berpindah ke tab Keamanan
    await tester.tap(find.text('Keamanan'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Kata Sandi'), findsOneWidget);
    expect(find.text('Kata Sandi Lama'), findsOneWidget);
    expect(find.text('Kata Sandi Baru'), findsOneWidget);

    // Coba submit kosong
    await tester.tap(find.text('Perbarui Kata Sandi'));
    await tester.pumpAndSettle();

    expect(find.text('Kata sandi lama wajib diisi'), findsOneWidget);
    expect(find.text('Kata sandi baru wajib diisi'), findsOneWidget);

    // Isi password lama 'admin123' (password default dummy admin)
    final textFields = find.byType(TextFormField);
    // Di tab Keamanan ada 3 field
    await tester.enterText(textFields.at(0), 'admin123');
    await tester.enterText(textFields.at(1), 'adminBaru123');
    await tester.enterText(textFields.at(2), 'adminBaru123');

    await tester.tap(find.text('Perbarui Kata Sandi'));
    await tester.pumpAndSettle();

    expect(find.text('Kata sandi berhasil diperbarui!'), findsOneWidget);
  });

  testWidgets('HomeScreen navigates to ProfileScreen via profile button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap icon profil pada header
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();

    // Verifikasi navigasi ke ProfileScreen berhasil
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Manajemen Profil'), findsOneWidget);
  });

  testWidgets('Admin Setting Screen renders tb_application configuration and updates values', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSettingScreen(applicationService: DummyApplicationService()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verifikasi elemen-elemen tb_application tampil
    expect(find.text('Pengaturan Aplikasi'), findsOneWidget);
    expect(find.text('Profil & Instansi'), findsOneWidget);
    expect(find.text('PT Karaoke Musik Nusantara'), findsOneWidget);
    expect(find.text('Karaoke Mobile App'), findsOneWidget);
    expect(find.text('Status Iklan Utama'), findsOneWidget);
    expect(find.text('Status Iklan Bawah'), findsOneWidget);
    expect(find.text('Tautan Link'), findsWidgets);
    expect(find.text('Unggah Gambar'), findsWidgets);
    expect(find.text('Simpan Pengaturan'), findsOneWidget);

    // 2. Edit nama instansi
    final companyFinder = find.widgetWithText(TextFormField, 'PT Karaoke Musik Nusantara');
    await tester.enterText(companyFinder, 'PT Sing Star Indonesia');

    // 3. Simpan pengaturan
    await tester.tap(find.text('Simpan Pengaturan'));
    await tester.pumpAndSettle();

    // 4. Verifikasi notifikasi berhasil
    expect(find.text('Pengaturan aplikasi berhasil disimpan!'), findsOneWidget);
    expect(find.text('PT Sing Star Indonesia'), findsOneWidget);
  });
}

