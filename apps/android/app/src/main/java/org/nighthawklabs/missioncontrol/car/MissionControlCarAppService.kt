package org.nighthawklabs.missioncontrol.car

import android.content.Intent
import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.validation.HostValidator
import org.nighthawklabs.missioncontrol.core.model.MissionControlBrief

/**
 * Android Auto entry point bundled with the phone app.
 *
 * The phone remains the full Mission Control experience. This surface deliberately
 * exposes only a glanceable brief and a handoff to the phone's existing voice flow.
 */
class MissionControlCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        return if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            // Accept the Android Auto desktop/head-unit host while developing.
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(this)
                .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                .build()
        }
    }

    override fun onCreateSession(): Session = MissionControlCarSession()
}

private class MissionControlCarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen = DriveBriefScreen(carContext)
}

private class DriveBriefScreen(carContext: androidx.car.app.CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val brief = MissionControlBrief.current()
        val items = ItemList.Builder()
            .addItem(
                Row.Builder()
                    .setTitle(brief.nextTitle)
                    .addText(brief.nextLabel)
                    .addText(brief.nextDetail)
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle(brief.attentionLabel)
                    .addText(brief.attentionDetail)
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle("Hands-free voice")
                    .addText("An active phone conversation continues while Android Auto is in front.")
                    .build(),
            )
            .build()

        return ListTemplate.Builder()
            .setTitle("Mission Control")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(items)
            .setActionStrip(
                androidx.car.app.model.ActionStrip.Builder()
                    .addAction(
                        Action.Builder()
                            .setTitle("Open on phone")
                            .setOnClickListener {
                                carContext.startCarApp(
                                    Intent(Intent.ACTION_MAIN).setPackage(carContext.packageName),
                                )
                            }
                            .build(),
                    )
                    .build(),
            )
            .build()
    }
}
