plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.lmdigital.mulialand"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lmdigital.mulialand"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
    }
    
    flavorDimensions += "environment"
    
        productFlavors {
            create("dev") {
                dimension = "environment"
                applicationId = "com.lmdigital.iuranwarga"
                applicationIdSuffix = ".dev"
            }
            create("prod") {
                dimension = "environment"
                applicationId = "com.lmdigital.mulialand"
            }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.11.0"))
}
flutter {
    source = "../.."
}
