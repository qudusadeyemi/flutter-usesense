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
        // 28, matching the native ai.usesense:sdk requirement (minSdk 28 since
        // SDK v4.1). Declaring a lower value here is dishonest — the release
        // manifest merge fails against the SDK's own minSdk. Consuming apps must
        // therefore also set minSdkVersion 28.
        minSdk = 28
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
    // central.sonatype.com/artifact/ai.usesense/sdk. 4.6.5 is the floor:
    // earlier builds could hang forever on "Finalizing Enrollment" because
    // the Play Integrity token request had no timeout and the signal upload
    // joined it unbounded, wedging the verification before a single request
    // was sent. Anything below this strands subjects on Android.
    // 4.6.6 is the floor: below it an upload that arrived incomplete was
    // reported as `provider`, so the runner told a subject holding a perfectly
    // good document that verification was "temporarily unavailable" and
    // offered a retry that re-sent identical bytes.
    // 4.6.7 is the floor: from it the runner reports whether the subject
    // scanned the document or chose a file, so failure guidance can name an
    // action they can actually take. Below it the server guesses from config.
    // 4.7.0 is the floor: below it frames_manifest reported a hardcoded
    // 640x480 regardless of what was captured. That is right for the legacy
    // path but wrong for v4, which captures 1280x720, and the server now
    // scales its screen-replay sharpness thresholds off that value, so
    // under-reporting made spoof detection more permissive on the better
    // capture path. 4.7.0 reports the real encoded size, caps frames at 960,
    // gzips the metadata, raises the 30s upload write timeout to 300s, and
    // emits real upload progress.
    implementation("ai.usesense:sdk:4.7.0")

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
