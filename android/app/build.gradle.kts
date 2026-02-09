plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.asg.asg"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "app.asg.asg"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildTypes {
        getByName("debug") {
            // Optional: add debug suffix if needed
            applicationIdSuffix = ".debug"
            resValue("string", "app_name", "ASG Debug")
        }

        getByName("release") {
            resValue("string", "app_name", "Auto Silent Gathering")
            // Signing config should go here
            signingConfig = signingConfigs.getByName("debug") // Replace with release config if signing
        }
    }
}

flutter {
    source = "../.."
}
