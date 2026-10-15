# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Services Cast Framework
-keep class com.google.android.gms.cast.** { *; }
-keep interface com.google.android.gms.cast.** { *; }
-keep class com.felnanuke.google_cast.** { *; }

# AndroidX Room / WorkManager
# Room membuat implementasi database (mis. WorkDatabase_Impl) lewat reflection
# dengan memanggil constructor tanpa argumen. R8 menghapus constructor itu di
# build release sehingga muncul crash:
#   "Failed to create an instance of androidx.work.impl.WorkDatabase"
# WorkManager ditarik secara transitif oleh SDK Ads/Cast dan diinisialisasi
# otomatis lewat androidx.startup pada saat proses aplikasi dimulai.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-dontwarn androidx.room.paging.**

# WebView & JavaScript interfaces (digunakan oleh youtube_player_iframe)
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class android.webkit.** { *; }

# Preserve source file and line number attributes for crash reports
-keepattributes SourceFile,LineNumberTable

# Flutter Deferred Components / Play Core (Suppress missing classes warnings)
-dontwarn com.google.android.play.core.**
