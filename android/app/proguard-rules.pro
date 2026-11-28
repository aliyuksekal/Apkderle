# flutter_local_notifications planlı bildirimleri Gson ile saklar; R8 bunları
# silerse sürüm derlemesinde bildirimler kurulamaz ("Missing type parameter").
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# WorkManager / Room: veritabanı sınıfı yansıtmayla (reflection) oluşturulur.
# R8 tam modunda kurucusu silinirse uygulama açılışta çöker:
# "NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init>"
-keep class * extends androidx.room.RoomDatabase { <init>(...); *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { <init>(); }
