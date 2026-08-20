plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "it.quiz.tabellone"
    // Segue la versione che l'SDK Flutter considera stabile (36 con Flutter 3.47),
    // cosi' un aggiornamento dell'SDK non lascia indietro il progetto.
    compileSdk = flutter.compileSdkVersion
    // ndkVersion non e' dichiarata: l'app non ha codice nativo proprio e
    // nessun NDK e' installato. Se un plugin ne avra' bisogno, il fallimento
    // sara' esplicito invece di scaricare centinaia di MB in silenzio.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "it.quiz.tabellone"
        // Fissata a mano e non ereditata da flutter.minSdkVersion: 24 e' un
        // requisito di progetto, e deve rompere il build se l'SDK lo alza.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Firma di debug: la configurazione di firma vera arriva con il
            // deploy, che e' fuori dall'ambito di questo rifacimento. Serve
            // perche' `flutter run --release` funzioni per i test in profile.
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
