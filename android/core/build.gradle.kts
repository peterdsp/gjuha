// The shared domain, as a pure Kotlin library.
//
// Deliberately plain JVM rather than an Android or Kotlin Multiplatform module.
// Everything in here is value types and pure functions, so it needs no Android
// SDK, its tests run in about a second, and it can be lifted into a `commonMain`
// source set later without touching a line of it. The Android app module will
// depend on this; nothing in here may depend on the app.
plugins {
    kotlin("jvm")
    kotlin("plugin.serialization") version "2.1.20"
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "failed", "skipped")
    }
}
