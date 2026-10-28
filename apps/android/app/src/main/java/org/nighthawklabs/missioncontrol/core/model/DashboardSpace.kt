package org.nighthawklabs.missioncontrol.core.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Checklist
import androidx.compose.material.icons.outlined.Checkroom
import androidx.compose.material.icons.outlined.Devices
import androidx.compose.material.icons.outlined.DirectionsCar
import androidx.compose.material.icons.outlined.FolderOpen
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import org.nighthawklabs.missioncontrol.ui.theme.Attention
import org.nighthawklabs.missioncontrol.ui.theme.Reminder
import org.nighthawklabs.missioncontrol.ui.theme.Signal
import org.nighthawklabs.missioncontrol.ui.theme.Telemetry

enum class DashboardSpace(
    val label: String,
    val icon: ImageVector,
    val accent: Color,
    val summary: String,
) {
    Tasks("Tasks", Icons.Outlined.Checklist, Signal, "A timeline that keeps your day moving."),
    Projects("Projects", Icons.Outlined.FolderOpen, Telemetry, "Repositories and workstreams when you need them."),
    Garage("Garage", Icons.Outlined.DirectionsCar, Attention, "Vehicle maintenance and driving data."),
    Devices("Devices", Icons.Outlined.Devices, Telemetry, "Your systems, services, and signals."),
    Pantry("Pantry", Icons.Outlined.Inventory2, Signal, "Inventory, use-soon items, and shopping."),
    Wardrobe("Wardrobe", Icons.Outlined.Checkroom, Reminder, "Outfits, care, and what is ready to wear."),
}

data class AttentionItem(
    val time: String,
    val title: String,
    val detail: String,
    val accent: Color,
)
