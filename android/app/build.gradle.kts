plugins {
    id("com.android.application")
    kotlin("android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.gjuha.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.gjuha.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    buildFeatures {
        compose = true
    }

    sourceSets {
        named("main") {
            kotlin.srcDir("src/main/kotlin")
            // The course content is NOT copied into this module. The seed under
            // Gjuha/Data/Seed is the single source of truth for both platforms,
            // and it is read straight from there by the packaging task below, so
            // a word cannot say one thing on iPhone and another on Android.
            assets.srcDir(layout.buildDirectory.dir("generated/seed"))
        }
    }
}

/**
 * Copies the iOS app's seed into this module's assets at build time.
 *
 * A copy checked into the Android tree would drift the first time either side
 * changed a word, and the drift would be invisible until a learner noticed the
 * two apps disagreeing. Copying at build time means there is exactly one file
 * to edit and the Android build fails loudly if it goes missing.
 */
val copySeed by tasks.registering(Copy::class) {
    val seed = rootProject.layout.projectDirectory.dir("../Gjuha/Data/Seed")
    from(seed) {
        include("**/*.json")
    }
    into(layout.buildDirectory.dir("generated/seed/seed"))
    doFirst {
        require(seed.asFile.isDirectory) {
            "Seed content not found at ${seed.asFile.canonicalPath}. " +
                "The Android build reads the iOS seed directly rather than keeping a copy."
        }
    }
}

tasks.named("preBuild") { dependsOn(copySeed) }

dependencies {
    implementation(project(":core"))

    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Glance is the Compose-shaped way to build an app widget, and the nearest
    // Android equivalent of WidgetKit.
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation(kotlin("test"))
}
