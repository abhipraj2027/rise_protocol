import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Resolved from, in order:
//   1. android/key.properties (local dev — gitignored, never committed)
//   2. RELEASE_* environment variables (CI — populated from GitHub Actions
//      secrets; see .github/workflows/build.yml)
// If any piece is missing or blank, the release build type falls back to
// debug signing, so every other build (branches, PRs, sideload testing)
// keeps working before the real keystore is wired up anywhere.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(propertyKey: String, envKey: String): String? =
    (keystoreProperties.getProperty(propertyKey) ?: System.getenv(envKey))
        ?.takeIf { it.isNotBlank() }

val releaseStoreFile: String? = signingValue("storeFile", "RELEASE_STORE_FILE")
val releaseStorePassword: String? = signingValue("storePassword", "RELEASE_STORE_PASSWORD")
val releaseKeyAlias: String? = signingValue("keyAlias", "RELEASE_KEY_ALIAS")
val releaseKeyPassword: String? = signingValue("keyPassword", "RELEASE_KEY_PASSWORD")
val hasReleaseSigning: Boolean =
    releaseStoreFile != null &&
        releaseStorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null

android {
    namespace = "com.riseprotocol.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.riseprotocol.app"
        // minSdk 26 is required for setShowWhenLocked / setTurnScreenOn, which
        // the ringing Activity relies on to force itself over the lock screen.
        minSdk = 26
        // Google Play requires new apps/updates to target the latest Android
        // (API 36 from 31 Aug 2026); Flutter's plugin supplies the value.
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml / --build-number. When using
        // split APKs, 1000 * ABI_VERSION is added automatically by Flutter.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            // Real keystore when available (see above); debug-signed
            // otherwise so sideload/CI builds keep working regardless.
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
