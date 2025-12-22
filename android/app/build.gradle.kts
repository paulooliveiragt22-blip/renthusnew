plugins {
    id("com.android.application")
    // Firebase / Google services
    id("com.google.gms.google-services")
    // Kotlin
    id("kotlin-android")
    // Flutter
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.renthus_new"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Desugaring + Java 11
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.renthus_new"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    // ⛔️ REMOVIDO: splits { abi { ... } }
    // Deixamos o Flutter / Gradle gerenciar as ABIs automaticamente

    buildTypes {
        // Build de release (Play Store / produção / teste leve)
        getByName("release") {
            // Por enquanto, assina com a debug pra facilitar testes
            signingConfig = signingConfigs.getByName("debug")

            // reduz tamanho do APK
            isMinifyEnabled = true
            isShrinkResources = true

            // Usa R8 com regras padrão + seu proguard-rules.pro
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }

        // Build de debug (flutter run normal)
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Evita alguns conflitos de recursos
    packagingOptions {
        resources {
            excludes += "META-INF/*"
        }
    }
}

dependencies {
    // Desugaring para usar APIs Java modernas com minSdk baixo
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
