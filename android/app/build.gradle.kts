import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
    // クラッシュレポート（Firebase Crashlytics）
    id("com.google.firebase.crashlytics")
}

// 本番署名用のキーストア情報。android/key.properties（Gitには含めない秘密ファイル）が
// あればそちらを使い、無ければリリースビルドもdebug鍵で署名する（CI環境でこのファイルを
// 用意し忘れてもビルド自体は通るようにするためのフォールバック）。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:34.17.0"))


  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")

  // クラッシュレポート。-ndk側はJava/Kotlin層だけでなくネイティブ層のクラッシュも捕捉する。
  implementation("com.google.firebase:firebase-crashlytics")
  implementation("com.google.firebase:firebase-crashlytics-ndk")

  // flutter_local_notificationsが要求するcore library desugaring用ランタイム。
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

android {
    namespace = "com.biffi.savepoint"
    // permission_handler_androidがSDK 37でのコンパイルを要求するため、Flutter既定値
    // （flutter.compileSdkVersion）より明示的に高いバージョンを指定する。
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications（積みゲーリマインダー）が要求するJava 8+ API
        // desugaringを有効化する。
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.biffi.savepoint"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // android/key.properties が用意されている場合は本番用アップロード鍵で署名する。
            // 無い場合（ローカルでの `flutter run --release` 等）はdebug鍵にフォールバックする。
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // ネイティブ層（NDK）のクラッシュもシンボリケートできるよう、ビルド時に
            // シンボル情報をCrashlyticsへ自動アップロードする。
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                nativeSymbolUploadEnabled = true
            }
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
