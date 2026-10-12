package com.kumarabd.missioncontrol

import android.app.Application
import com.clerk.api.Clerk

class MissionControlApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Clerk.initialize(this, publishableKey = getString(R.string.clerk_publishable_key))
    }
}
