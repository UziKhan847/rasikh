# R8 keep rules for release builds (debug builds aren't shrunk, which is why
# a missing rule shows up only in release).

# Plugins that call their Kotlin side through JNI (Pigeon JNI) look classes
# and methods up by name at run time, so R8 must leave them as they are.
# Without these, shared_preferences 2.5 fails on its first read
# (NoSuchMethodError ... SharedPreferencesApiRegistrar.getAll) and the app
# never gets past the splash screen.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
# Kotlin runtime types those JNI signatures name.
-keep class kotlin.coroutines.Continuation { *; }
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
