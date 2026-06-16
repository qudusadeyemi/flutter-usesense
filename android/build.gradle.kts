plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

group = "com.usesense.flutter"
version = "2.0.1"

android {
    namespace = "com.usesense.flutter"
    compileSdk = 35

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
}

dependencies {
    // UseSense Android SDK — published to Maven Central at
    // central.sonatype.com/artifact/ai.usesense/sdk. Pinned to 4.3.0,
    // the release that adds the V4 capture API + Flows runner (matches
    // the iOS SDK 4.3.0 this plugin's podspec depends on).
    implementation("ai.usesense:sdk:4.3.0")

    // Flutter embedding (provided by the Flutter build system)
    compileOnly("io.flutter:flutter_embedding_debug:1.0.0-")
}
