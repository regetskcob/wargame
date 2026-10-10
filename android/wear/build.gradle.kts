// Only a manifest: what turns the Android app into the Wear OS app. The app
// depends on it when built with `-P wear=true`, see app/build.gradle.kts.
plugins {
    id("com.android.library")
}

android {
    namespace = "de.regetskcob.wargame.wear"
    compileSdk = 36

    defaultConfig {
        // Wear OS 3, the first version on the Galaxy Watch 4 and the
        // Pixel Watch.
        minSdk = 30
    }
}
