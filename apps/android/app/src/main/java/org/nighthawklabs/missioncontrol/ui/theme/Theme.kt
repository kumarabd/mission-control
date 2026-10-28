package org.nighthawklabs.missioncontrol.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

private val DarkColorScheme = darkColorScheme(
    primary = DesignTokens.tintDark,
    secondary = DesignTokens.telemetryDark,
    tertiary = DesignTokens.attentionDark,
    background = DesignTokens.canvasDark,
    surface = DesignTokens.surfaceDark,
    surfaceVariant = DesignTokens.lineDark,
    onPrimary = DesignTokens.actionInkDark,
    onBackground = DesignTokens.inkDark,
    onSurface = DesignTokens.inkDark,
    onSurfaceVariant = DesignTokens.quietTextDark,
    outline = DesignTokens.lineDark,
)

private val LightColorScheme = lightColorScheme(
    primary = DesignTokens.tintLight,
    secondary = DesignTokens.telemetryLight,
    tertiary = DesignTokens.attentionLight,
    background = DesignTokens.canvasLight,
    surface = DesignTokens.surfaceLight,
    surfaceVariant = Color(0xFFE0E6DE),
    onPrimary = DesignTokens.actionInkLight,
    onBackground = DesignTokens.inkLight,
    onSurface = DesignTokens.inkLight,
    onSurfaceVariant = DesignTokens.quietTextLight,
    outline = DesignTokens.lineLight,
)

// Cards 16dp, small chips 12dp, sheets 24dp: the same radii as the web console.
val MissionShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(24.dp),
)

@Composable
fun MissionControlTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        shapes = MissionShapes,
        content = content
    )
}

/** The accent colours are tuned for dark surfaces; in light mode text and icons use the darker web-console tones. */
@Composable
fun Color.readable(): Color = if (isSystemInDarkTheme()) this else when (this) {
    Signal -> DesignTokens.tintLight
    Attention -> DesignTokens.attentionLight
    Telemetry -> DesignTokens.telemetryLight
    Reminder -> DesignTokens.reminderLight
    else -> this
}
