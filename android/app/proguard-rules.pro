# Open-source code. Copyright Mohamed Zaitoon 2025-2026.

-keep class com.mohamedzaitoon.hrmstore.NativeBridge { *; }

-keepclasseswithmembernames class * {
    native <methods>;
}

-keepnames class com.mohamedzaitoon.hrmstore.*
-keepnames class com.mohamedzaitoon.hrmstore.HrmStoreApp

-keep class com.mohamedzaitoon.hrmstore.BuildConfig { *; }
-keep class com.mohamedzaitoon.hrmstore.R { *; }

-keep class com.mohamedzaitoon.hrmstore.databinding.** { *; }
-keep class **BR

-keep class com.mohamedzaitoon.hrmstore.R { *; }
-keep class com.mohamedzaitoon.hrmstore.R$* { *; }

-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

-keep class com.google.firebase.remoteconfig.** { *; }
-dontwarn com.google.firebase.remoteconfig.**

-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

-keep class com.android.volley.** { *; }
-keep interface com.android.volley.** { *; }
-dontwarn com.android.volley.**

-dontwarn retrofit2.**
-dontwarn okio.**

-dontwarn androidx.**

-keep class androidx.work.** { *; }

-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

-dontnote **
-dontwarn javax.annotation.**
-dontwarn sun.misc.Unsafe
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**


-renamesourcefileattribute HrmStoreApp
-keepattributes SourceFile,LineNumberTable
