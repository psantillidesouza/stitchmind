# Flutter / engine — o plugin do Flutter já injeta as regras principais.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase Auth + Google Sign-In + Play services (mantém modelos/callbacks)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# Sign in with Apple (usa web/oauth, sem reflexão pesada)
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }

# Modelos serializados via reflexão (defensivo p/ libs de JSON)
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
