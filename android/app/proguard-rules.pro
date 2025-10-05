# Flutter default rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.BuildConfig { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# File Picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Device Info Plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# Flutter App Auth
-keep class io.crossingthestreams.flutterappauth.** { *; }

# Firebase Auth
-keep class io.flutter.plugins.firebase.auth.** { *; }

# Firebase Database
-keep class io.flutter.plugins.firebase.database.** { *; }

# Firebase Messaging
-keep class io.flutter.plugins.firebase.messaging.** { *; }

# Firebase Storage
-keep class io.flutter.plugins.firebase.storage.** { *; }

# Flutter Native Splash
-keep class net.jonhanson.flutter_native_splash.** { *; }

# Keep annotations (needed for some plugins)
-keep class androidx.annotation.** { *; }
-keep class com.google.gson.** { *; }

# Keep Parcelable classes (common in Flutter plugins)
-keep class * implements android.os.Parcelable { *; }

# Keep classes referenced in XML (like Activities/Services/Receivers)
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep Play Core classes
-keep class com.google.android.play.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
