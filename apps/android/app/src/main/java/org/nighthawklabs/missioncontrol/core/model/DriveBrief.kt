package org.nighthawklabs.missioncontrol.core.model

/**
 * Platform-neutral, at-a-glance data for constrained surfaces such as Android Auto.
 *
 * This is intentionally free of Compose and Android Auto types so it can become a
 * gateway-backed shared read model when the dashboard's local mock data is replaced.
 */
data class DriveBrief(
    val nextLabel: String,
    val nextTitle: String,
    val nextDetail: String,
    val attentionLabel: String,
    val attentionDetail: String,
)

object MissionControlBrief {
    fun current(): DriveBrief = DriveBrief(
        nextLabel = "Next · 2:30 PM",
        nextTitle = "Dentist",
        nextDetail = "Leave in 20 min",
        attentionLabel = "Today",
        attentionDetail = "Use the spinach · pantry reminder",
    )
}
