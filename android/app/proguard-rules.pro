# T4.2: Flutter + plugin keep rules for R8 full-mode (minifyEnabled true).
#
# Flutter's own keep rules ship with the Flutter Gradle plugin
# (dev.flutter.flutter-gradle-plugin) via the merged
# proguard-android-optimize.txt baseline; this file adds app-specific
# rules on top. Anything here is appended after the default file.
#
# When a new plugin is added and the release APK crashes on first
# launch with a NoSuchMethodError / ClassNotFoundException, the fix
# is usually a single -keep line below referencing the missing class.

# --- Flutter / Dart embedding ------------------------------------------
# (Flutter ships its own rules; the two below cover the most common
# regression when an app extends FlutterApplication / FlutterActivity.)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# --- Native methods (JNI) ----------------------------------------------
# Anything marked `native` must not be renamed — R8 can't follow the
# symbol across the JNI boundary.
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- Parcelables / Serializables ---------------------------------------
# Standard Android reflection-based serialization — Android's runtime
# recreates these from the CREATOR field by name.
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# --- Plugin-specific keeps --------------------------------------------
# flutter_local_notifications (T3.4) uses Gson to deserialize scheduled
# notification payloads from SharedPreferences. Gson needs the model
# classes by name; the plugin's own proguard rules cover its internals
# but the user-supplied NotificationDetails subclasses need to survive.
-keep class com.dexterous.** { *; }

# shared_preferences (T3.2 settings) is a pure-Java plugin with no
# reflection needs; no extra rules.

# qr_flutter (T3.2) renders via Skia — no reflection.
# mobile_scanner (T3.2) wraps MLKit BarcodeScanning which uses CameraX
# underneath; CameraX itself is reflection-heavy and ships its own
# consumer rules. No extra rules here unless we hit a runtime crash.

# --- Logging (strip in release) ----------------------------------------
# Aggressively strip android.util.Log calls from release binaries to
# shave a few KB and keep noisy stack traces out of the APK.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}