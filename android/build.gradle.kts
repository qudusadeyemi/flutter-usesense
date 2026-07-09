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
}

// Kotlin JVM target lives in the top-level `kotlin {}` block, NOT inside
// `android { kotlinOptions { ... } }`. Newer Kotlin Gradle plugins (shipped
// with recent stable Flutter) mark `kotlinOptions`/`jvmTarget` as
// deprecation-level ERROR, and having `kotlinOptions` inside `android {}` also
// forces the `android` accessor to resolve to the deprecated LibraryExtension
// type — both become hard script-compilation errors. The compilerOptions DSL
// is the forward-compatible form.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // UseSense Android SDK — published to Maven Central at
    // central.sonatype.com/artifact/ai.usesense/sdk. Pinned to 4.3.0,
    // the release that adds the V4 capture API + Flows runner (matches
    // the iOS SDK 4.3.0 this plugin's podspec depends on).
    implementation("ai.usesense:sdk:4.6.1")

    // NOTE: do NOT declare io.flutter:flutter_embedding_* here. The Flutter
    // Gradle plugin injects it into every plugin subproject at build time
    // (PluginHandler.addApiDependencies -> "io.flutter:flutter_embedding_
    // $buildMode:1.0.0-$engineVersion"), pinned to the *consuming app's*
    // engine version and the matching build variant (debug/profile/release).
    // Hardcoding a coordinate here pins a fixed engine hash + the debug
    // variant, which breaks any integrator whose Flutter SDK differs from ours
    // ("inconsistent module metadata found ... bad version") and leaks the
    // debug embedding into release builds. The embedding API classes are on
    // the compile classpath via that injection.
}
