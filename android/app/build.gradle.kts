plugins {
    id("com.android.application")
    // this one has to go after the android/kotlin plugins or it breaks, learned that the hard way
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.cross_guard_app"
    // had to hardcode this to 37 bc permission_handler wants sdk 37 but
    // flutter defaults to 36 rn, so it kept failing until i bumped it
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications literally will not build without this
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: prob shouldnt ship with the example applicationId lol, change later
        applicationId = "com.example.cross_guard_app"
        // these just pull from pubspec so dont mess with them unless u know why
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: need a real signing config eventually, using debug keys for now so it just builds
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
