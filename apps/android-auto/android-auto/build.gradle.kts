plugins {
    id("com.android.application")
}

android {
    namespace = "com.kumarabd.missioncontrol"
    compileSdk = 36

    defaultConfig {
        // Android Auto is part of the existing Android phone app, not a second app.
        applicationId = "org.nighthawklabs.missioncontrol"
        minSdk = 29
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }
}

dependencies {
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0")
    // This release is compatible with the Kotlin compiler bundled with AGP 9.1.
    implementation("com.clerk:clerk-android-api:1.0.16")
    implementation("androidx.media3:media3-exoplayer:1.11.0")
    implementation("androidx.media3:media3-session:1.11.0")
}
