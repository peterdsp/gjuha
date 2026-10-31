# Keep rules for the release build.
#
# These are load bearing. R8 shrinks by reachability, and the learning domain
# is reached through kotlinx-serialization's generated serializers, which R8
# cannot see from the call sites. Without these, a release build compiles
# cleanly and then fails at runtime the first time it reads the seed, which is
# on the launch path.

-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**

# The canonical kotlinx-serialization rules: keep each @Serializable type's
# Companion and the serializer() it hands out.
-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}

-if @kotlinx.serialization.Serializable class ** {
    static **$* *;
}
-keepclassmembers class <2>$<3> {
    kotlinx.serialization.KSerializer serializer(...);
}

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}

# The shared domain types are decoded from the bundled seed by name, so their
# members must survive. Shrinking them would make the app launch to an empty
# course rather than crash, which is worse: it looks like missing content.
-keep class com.gjuha.core.** { *; }

# Glance renders the widget through generated code the app never calls
# directly.
-keep class androidx.glance.appwidget.** { *; }
-keep class com.gjuha.app.widget.** { *; }
