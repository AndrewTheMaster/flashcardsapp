plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flashcards_app"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flashcards_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Use multiDex to support larger app size
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // Add packaging options to exclude problematic TensorFlow Lite native libraries
    packaging {
        resources {
            excludes += listOf(
                "lib/arm64-v8a/libtensorflowlite_c.so",
                "lib/armeabi-v7a/libtensorflowlite_c.so",
                "lib/x86/libtensorflowlite_c.so",
                "lib/x86_64/libtensorflowlite_c.so",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0"
            )
        }
    }
    
    // Add lint options to ignore issues
    lint {
        disable.add("InvalidPackage")
        checkReleaseBuilds = false
        abortOnError = false
    }
    
    // Add configurations to prevent duplicate class issues
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core-ktx:1.9.0")
            force("androidx.appcompat:appcompat:1.6.1")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.8.22")
    implementation("androidx.multidex:multidex:2.0.1")
}
