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
