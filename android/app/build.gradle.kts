// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.variant.FilterConfiguration
import com.android.build.gradle.BaseExtension
import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.firebase.crashlytics")
}


val keystorePropertiesFile = file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

configure<ApplicationExtension>{
    namespace = "com.mohamedzaitoon.hrmstore"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["applicationName"] = ".HrmStoreApp"
    }

    flavorDimensions.add("default")

    productFlavors {
        create("user") {
            dimension = "default"
            applicationId = "com.mohamedzaitoon.hrmstore"
            resValue("string", "app_name", "HRM Store")
            minSdk = 26
            manifestPlaceholders["applicationName"] = ".HrmStoreApp"
        }

        create("admin") {
            dimension = "default"
            applicationIdSuffix = ".admin"
            resValue("string", "app_name", "HRM Store (Admin)")
            minSdk = 35
            // Fixed admin version
            versionName = "2.3"
            versionCode = 230
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["store_file"] as String)
                storePassword = keystoreProperties["store_password"] as String
                keyAlias = keystoreProperties["key_alias"] as String
                keyPassword = keystoreProperties["key_password"] as String
            }
        }
        getByName("debug") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["store_file"] as String)
                storePassword = keystoreProperties["store_password"] as String
                keyAlias = keystoreProperties["key_alias"] as String
                keyPassword = keystoreProperties["key_password"] as String
            }
        }
    }

    buildTypes {
        release {
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = false
            }

                signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    packaging {
        resources {
            excludes.add("META-INF/androidx.**")
            excludes.add("META-INF/kotlin.**")
            excludes.add("META-INF/com.android.build.**")
            excludes.add("META-INF/LICENSE*")
            excludes.add("META-INF/NOTICE*")
            excludes.add("META-INF/AL2.0")
            excludes.add("META-INF/LGPL2.1")
            excludes.add("META-INF/DEPENDENCIES")
            excludes.add("**/*.proto")
            excludes.add("META-INF/services/com.fasterxml.**")
            excludes.add("**/*.properties")
            excludes.add("**/*.version")
            excludes.add("**/.*")
            excludes.add("**/ABOUT")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.github.mohamed-zaitoon:apputilx:1.3.0")
    implementation("com.onesignal:OneSignal:5.1.20")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
