plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

group = "com.usesense.flutter"
version = "2.0.0"

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
    // central.sonatype.com/artifact/ai.usesense/sdk. Pinned to ^4.2.1
    // because that's the first release with the centering fix for the
    // terminal verification screens and the proper vanniktech-based
    // publish artifact shape with sources + javadoc JARs.
    implementation("ai.usesense:sdk:4.2.1")

    // Flutter embedding (provided by the Flutter build system)
    compileOnly("io.flutter:flutter_embedding_debug:1.0.0-")
}
