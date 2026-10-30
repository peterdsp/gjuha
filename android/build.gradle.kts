// Root build file. Plugins are declared here and applied in the modules.
plugins {
    id("com.android.application") version "8.7.3" apply false
    kotlin("android") version "2.1.20" apply false
    kotlin("jvm") version "2.1.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.20" apply false
}
