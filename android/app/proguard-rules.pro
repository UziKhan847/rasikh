# R8 keep rules for release builds (debug builds aren't shrunk, which is why
# a missing rule shows up only in release).

# Plugins that call their Kotlin side through JNI (Pigeon JNI) look classes
# and methods up by name at run time, so R8 must leave them as they are.
# Without these, shared_preferences 2.5 fails on its first read
# (NoSuchMethodError ... SharedPreferencesApiRegistrar.getAll) and the app
# never gets past the splash screen.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
# Kotlin runtime types reached the same way — by the plugins' signatures,
# and by package:jni when it awaits a Kotlin suspend function
# (CoroutineSingletons, IntrinsicsKt, Result). All of them, from the jni
# 1.1 / shared_preferences 2.5 / path_provider 2.3 sources:
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.enums.EnumEntries { *; }
-keep class kotlin.jvm.internal.DefaultConstructorMarker { *; }

# flutter_local_notifications stores scheduled reminders with Gson, which
# needs generic signatures and its TypeToken subclasses intact.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
