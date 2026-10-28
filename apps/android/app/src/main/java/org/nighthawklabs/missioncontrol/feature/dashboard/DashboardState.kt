package org.nighthawklabs.missioncontrol.feature.dashboard

import org.nighthawklabs.missioncontrol.core.model.AttentionItem
import org.nighthawklabs.missioncontrol.core.model.DashboardSpace
import org.nighthawklabs.missioncontrol.core.model.MissionControlBrief
import org.nighthawklabs.missioncontrol.ui.theme.Attention
import org.nighthawklabs.missioncontrol.ui.theme.Reminder
import org.nighthawklabs.missioncontrol.ui.theme.Signal

data class DashboardState(
    val selectedSpace: DashboardSpace? = null,
    val attention: List<AttentionItem> = dashboardAttentionItems(),
)

private fun dashboardAttentionItems(): List<AttentionItem> {
    val brief = MissionControlBrief.current()
    return listOf(
        AttentionItem("NOW", "Review release notes", "Focus block · 30 min", Signal),
        AttentionItem(brief.nextLabel, brief.nextTitle, brief.nextDetail, Attention),
        AttentionItem(brief.attentionLabel, brief.attentionDetail, "Needs attention", Reminder),
    )
}
