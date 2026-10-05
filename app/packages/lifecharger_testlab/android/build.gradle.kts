group = "com.lifecharger.lifecharger_testlab"
version = "1.0"

// The Android Gradle plugin comes from the app's own plugin management (no buildscript here), so the
// plugin builds with whatever AGP version the app uses.
plugins {
    id("com.android.library")
}

android {
    namespace = "com.lifecharger.lifecharger_testlab"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 21
    }
}
