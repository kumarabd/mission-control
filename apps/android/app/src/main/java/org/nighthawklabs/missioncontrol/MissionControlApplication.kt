package org.nighthawklabs.missioncontrol

import android.app.Application
import com.clerk.api.Clerk

class MissionControlApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Clerk.initialize(this, publishableKey = BuildConfig.CLERK_PUBLISHABLE_KEY)
    }
}
