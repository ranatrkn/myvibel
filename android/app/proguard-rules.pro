# flutter_local_notifications Gson TypeToken imzaları R8'de silinirse
# ScheduledNotificationBootReceiver açılışta çöker.
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }
