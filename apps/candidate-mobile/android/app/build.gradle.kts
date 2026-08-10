plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google validates the signing certificate's SHA-1 against the Android OAuth
// client, and Gradle generates a throwaway debug keystore on any machine that
// lacks one -- so every CI run would otherwise sign with a different, and
// therefore unregisterable, fingerprint. When FLORA_REVIEW_KEYSTORE points at
// a keystore, debug builds are signed with it instead, giving review builds a
// stable identity. Absent it, nothing changes and the ordinary debug keystore
// is used, so local builds are unaffected.
val reviewKeystorePath: String? = System.getenv("FLORA_REVIEW_KEYSTORE")
val reviewKeystore = reviewKeystorePath?.let(::File)?.takeIf { it.exists() }

android {
    namespace = "com.example.candidate_mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        if (reviewKeystore != null) {
            getByName("debug") {
                storeFile = reviewKeystore
                storePassword = System.getenv("FLORA_REVIEW_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("FLORA_REVIEW_KEY_ALIAS") ?: "flora-review"
                keyPassword = System.getenv("FLORA_REVIEW_KEY_PASSWORD")
                    ?: System.getenv("FLORA_REVIEW_KEYSTORE_PASSWORD")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.candidate_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
