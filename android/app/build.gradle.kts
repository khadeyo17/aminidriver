plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    //id("com.google.gms.google-services")
    id("com.google.gms.google-services") //version "4.4.2" apply false
}

android {
    namespace = "com.example.aminidriver"
    compileSdk = 35//flutter.compileSdkVersion
    //ndkVersion = flutter.ndkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
       // sourceCompatibility = JavaVersion.VERSION_11
       // targetCompatibility = JavaVersion.VERSION_11
    }
     dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    implementation("com.google.android.gms:play-services-maps:18.1.0")
    implementation("com.google.android.gms:play-services-location:21.0.1")
    implementation("com.google.firebase:firebase-messaging:23.4.1")
    //classpath("com.google.gms:google-services:4.3.15")
   // implementation("com.mapbox.mapboxsdk:mapbox-android-sdk:9.6.2")
    }

    kotlinOptions {
        jvmTarget = "17"
        //jvmTarget = JavaVersion.VERSION_11.toString()
    }
    java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
    }
    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.aminidriver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23//flutter.minSdkVersion
        targetSdk = 34//flutter.targetSdkVersion
        versionCode = 1//flutter.versionCode
        versionName = "1.0"//flutter.versionName
        multiDexEnabled=true
        manifestPlaceholders["appAuthRedirectScheme"] = "com.example.aminidriver"
        //manifestPlaceholders = [appAuthRedirectScheme: "com.example.aminidriver"]

    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")

        }
    }
}

flutter {
    source = "../.."
}
