# flutter_local_notifications planlı bildirimleri Gson ile saklar; R8 bunları
# silerse sürüm derlemesinde bildirimler kurulamaz ("Missing type parameter").
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
