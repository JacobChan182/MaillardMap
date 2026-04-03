import java.util.Properties
import org.gradle.api.Project

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

/** `local.properties` overrides `gradle.properties` / default. Retrofit expects a trailing `/`. */
fun resolvedApiBaseUrl(project: Project): String {
    val localFile = project.rootProject.file("local.properties")
    val props = Properties()
    if (localFile.exists()) {
        localFile.inputStream().use { props.load(it) }
    }
    val fromLocal = props.getProperty("MAILLARDMAP_API_BASE_URL")?.trim()
    val fromGradle = (project.findProperty("MAILLARDMAP_API_BASE_URL") as String?)?.trim()
    val chosen = fromLocal ?: fromGradle ?: "http://10.0.2.2:3000"
    return chosen.trimEnd('/') + "/"
}

android {
    namespace = "com.maillardmap"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.maillardmap"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        val apiBaseUrl = resolvedApiBaseUrl(project)
        buildConfigField("String", "API_BASE_URL", "\"${apiBaseUrl.replace("\\", "\\\\")}\"")

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
    }
}

dependencies {
    // Compose
    val composeBom = platform("androidx.compose:compose-bom:2024.01.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.compose.material:material")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.6")

    // Retrofit + serialization
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")

    // Lifecycle
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")

    // Room (minimal)
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")

    // Coil for images
    implementation("io.coil-kt:coil-compose:2.5.0")

    // v10 NDK27 variant: ELF segments aligned for 16 KB page devices (Android 15+). Do not add `android` without -ndk27.
    implementation("com.mapbox.maps:android-ndk27:10.19.1")
}
