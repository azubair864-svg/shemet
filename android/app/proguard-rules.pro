# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Agora RTC SDK rules
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# DeepAR SDK rules
-keep class ai.deepar.** { *; }
-dontwarn ai.deepar.**

# Firebase rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# JNI rules (Needed for Agora/DeepAR native libs)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Google Play Core rules (Billing & Updates)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-keep class com.android.billingclient.** { *; }
