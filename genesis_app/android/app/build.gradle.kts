import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("com.google.firebase.firebase-perf")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.worldo.ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.worldo.ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        providers.gradleProperty("worldoTargetAbi").orNull
            ?.takeIf { it.isNotBlank() }
            ?.let { targetAbi ->
                ndk {
                    abiFilters.clear()
                    abiFilters.add(targetAbi)
                }
            }
    }

    flavorDimensions += "app"
    productFlavors {
        create("production") {
            dimension = "app"
            applicationId = "com.worldo.ai"
        }
        create("internal") {
            dimension = "app"
            applicationId = "com.worldo.ai.internal"
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = false
            }
        }
    }

    signingConfigs {
        create("genesisAiSign") {
            storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("genesisAiSign")
        }

        release {
            signingConfig = signingConfigs.getByName("genesisAiSign")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

googleServices {
    missingGoogleServicesStrategy =
        com.google.gms.googleservices.GoogleServicesPlugin.MissingGoogleServicesStrategy.IGNORE
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core:1.18.0")
    implementation("androidx.core:core-splashscreen:1.2.0")
    implementation("com.google.android.gms:play-services-auth:21.4.0")
    implementation("com.google.android.gms:play-services-ads-identifier:18.3.0")
}

flutter {
    source = "../.."
}
