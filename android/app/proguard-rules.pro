########### Flutter / Engine / Plugins ###########

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }

########### Firebase (Core + Messaging) ###########

-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

########### Google Play Services ###########

-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

########### flutter_local_notifications ###########

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

########### location (plugin de localização) ###########

-keep class com.lyokone.location.** { *; }
-dontwarn com.lyokone.location.**

########### Play Core (Split Install / Deferred Components do Flutter) ###########
# -> É exatamente o que está dando erro de "Missing class ..."
#    Não usamos deferred components, então podemos simplesmente ignorar.

-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

########### Anotações / coisas genéricas ###########

-keepattributes *Annotation*
-dontwarn org.jetbrains.annotations.**

########### Sua aplicação ###########

-keep class com.example.renthus_new.MainActivity { *; }
-keep class com.example.renthus_new.** { *; }
