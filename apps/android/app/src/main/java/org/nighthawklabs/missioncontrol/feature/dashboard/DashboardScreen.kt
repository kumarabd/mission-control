package org.nighthawklabs.missioncontrol.feature.dashboard

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.NearMe
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.BottomSheetScaffold
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberBottomSheetScaffoldState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import org.nighthawklabs.missioncontrol.core.model.AttentionItem
import org.nighthawklabs.missioncontrol.core.model.DashboardSpace
import org.nighthawklabs.missioncontrol.ui.theme.Attention
import org.nighthawklabs.missioncontrol.ui.theme.GraphiteLine
import org.nighthawklabs.missioncontrol.ui.theme.QuietInk
import org.nighthawklabs.missioncontrol.ui.theme.Signal
import org.nighthawklabs.missioncontrol.ui.theme.readable
import com.clerk.api.Clerk
import com.clerk.api.network.serialization.ClerkResult
import com.clerk.api.sso.OAuthProvider
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun DashboardScreen(viewModel: DashboardViewModel, modifier: Modifier = Modifier) {
    var selectedSpace by remember { mutableStateOf<DashboardSpace?>(null) }
    var showAccountSheet by remember { mutableStateOf(false) }
    val assistantState by viewModel.uiState.collectAsState()
    val showConversationText by viewModel.showConversationText.collectAsState()
    val handsFreeEnabled by viewModel.handsFreeEnabled.collectAsState()
    val scope = rememberCoroutineScope()
    val workspaceSheet = rememberBottomSheetScaffoldState()
    val microphonePermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) viewModel.startVoiceInteraction() else viewModel.microphoneAccessDenied()
    }
    val state = remember { DashboardState() }

    LaunchedEffect(assistantState.requiresSignIn) {
        if (assistantState.requiresSignIn) showAccountSheet = true
    }

    BottomSheetScaffold(
        modifier = modifier.fillMaxSize(),
        scaffoldState = workspaceSheet,
        sheetPeekHeight = 104.dp,
        sheetShape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        sheetContainerColor = MaterialTheme.colorScheme.surface,
        sheetContentColor = MaterialTheme.colorScheme.onSurface,
        sheetDragHandle = {
            WorkspaceDrawerHandle(
                onClick = { scope.launch { workspaceSheet.bottomSheetState.expand() } },
            )
        },
        sheetContent = {
            WorkspaceDrawer(
                spaces = DashboardSpace.entries.toList(),
                onSpaceTap = { selectedSpace = it },
            )
        },
    ) { contentPadding ->
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(contentPadding)
                    .safeDrawingPadding(),
            ) {
                DashboardHeader(
                    showConversationText = showConversationText,
                    handsFreeEnabled = handsFreeEnabled,
                    onConversationTextVisibilityToggle = viewModel::toggleConversationTextVisibility,
                    onHandsFreeToggle = viewModel::toggleHandsFree,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 10.dp),
                )

                AssistantFocus(
                    assistantState = assistantState,
                    showConversationText = showConversationText,
                    onOrbTap = {
                        if (assistantState.requiresSignIn) {
                            showAccountSheet = true
                        } else if (assistantState.isInteracting) {
                            viewModel.stopOrInterruptAssistant()
                        } else {
                            microphonePermission.launch(Manifest.permission.RECORD_AUDIO)
                        }
                    },
                    modifier = Modifier
                        .align(Alignment.Center)
                        .fillMaxWidth()
                        .fillMaxHeight(),
                )
            }
        }
    }

    selectedSpace?.let { space ->
        SpaceDialog(space = space, onDismiss = { selectedSpace = null })
    }

    if (showAccountSheet) {
        AccountSheet(
            onDismiss = { showAccountSheet = false },
            onAuthenticated = {
                showAccountSheet = false
                viewModel.authenticationDidComplete()
            },
        )
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun AccountSheet(onDismiss: () -> Unit, onAuthenticated: () -> Unit) {
    val scope = rememberCoroutineScope()
    var signingIn by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 14.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.AccountCircle,
                contentDescription = null,
                tint = Signal,
                modifier = Modifier.size(34.dp),
            )
            Text("Bring your assistant online", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
            Text(
                "Sign in once to securely connect your assistant when you choose to speak.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Button(
                onClick = {
                    signingIn = true
                    error = null
                    scope.launch {
                        when (val result = Clerk.auth.signInWithOAuth(OAuthProvider.GOOGLE)) {
                            is ClerkResult.Success -> onAuthenticated()
                            is ClerkResult.Failure -> {
                                signingIn = false
                                error = result.throwable?.message ?: "Google sign-in couldn’t be completed."
                            }
                        }
                    }
                },
                enabled = !signingIn,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (signingIn) "Connecting…" else "Continue with Google")
            }
            error?.let { message ->
                Text(message, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun DashboardHeader(
    showConversationText: Boolean,
    handsFreeEnabled: Boolean,
    onConversationTextVisibilityToggle: () -> Unit,
    onHandsFreeToggle: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var now by remember { mutableStateOf(LocalDateTime.now()) }
    LaunchedEffect(Unit) {
        while (true) {
            now = LocalDateTime.now()
            delay(30_000)
        }
    }
    Row(modifier = modifier, verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.SpaceBetween) {
        Column {
            Text(now.format(DateTimeFormatter.ofPattern("h:mm a")), style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Light)
            Text(now.format(DateTimeFormatter.ofPattern("EEEE · MMMM d")), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Metric(label = "CLEAR", value = "21°", tint = Attention)
            Metric(label = "SYSTEMS", value = "4/4", tint = Signal)
            IconButton(onClick = onConversationTextVisibilityToggle) {
                Icon(
                    imageVector = if (showConversationText) Icons.Outlined.Visibility else Icons.Outlined.VisibilityOff,
                    contentDescription = if (showConversationText) {
                        "Hide spoken and response text"
                    } else {
                        "Show spoken and response text"
                    },
                )
            }
            IconButton(onClick = onHandsFreeToggle) {
                Icon(
                    imageVector = Icons.Outlined.GraphicEq,
                    contentDescription = if (handsFreeEnabled) {
                        "Turn off hands-free continuation"
                    } else {
                        "Turn on hands-free continuation"
                    },
                    tint = if (handsFreeEnabled) Signal else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun Metric(label: String, value: String, tint: Color) {
    Column(horizontalAlignment = Alignment.End) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, color = tint.readable())
    }
}

@Composable
private fun AssistantFocus(
    assistantState: AssistantUiState,
    showConversationText: Boolean,
    onOrbTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(modifier = modifier) {
        val small = maxWidth < 600.dp
        Column(
            modifier = Modifier
                .align(Alignment.Center)
                .widthIn(max = if (small) 300.dp else 440.dp)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            AssistantOrb(presence = assistantState.presence, onTap = onOrbTap, diameter = if (small) 246.dp else 310.dp)
            Spacer(Modifier.height(26.dp))
            AssistantBriefing(assistantState, showConversationText)
        }
    }
}

@Composable
private fun WorkspaceDrawerHandle(onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(role = Role.Button, onClick = onClick)
            .padding(top = 10.dp, bottom = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Surface(
            modifier = Modifier.size(width = 38.dp, height = 5.dp),
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.65f),
            shape = CircleShape,
        ) {}
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            Icon(Icons.Outlined.GraphicEq, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(17.dp))
            Text("Explore workspace", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun WorkspaceDrawer(spaces: List<DashboardSpace>, onSpaceTap: (DashboardSpace) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(start = 20.dp, end = 20.dp, bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            "Your workspace",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        spaces.chunked(3).forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                row.forEach { space ->
                    Surface(
                        modifier = Modifier
                            .weight(1f)
                            .height(92.dp)
                            .clickable(role = Role.Button) { onSpaceTap(space) }
                            .semantics { contentDescription = "Open ${space.label}" },
                        shape = RoundedCornerShape(20.dp),
                        color = space.accent.copy(alpha = 0.11f),
                        border = CardDefaults.outlinedCardBorder().copy(
                            brush = androidx.compose.ui.graphics.SolidColor(space.accent.copy(alpha = 0.36f)),
                        ),
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center,
                        ) {
                            Icon(space.icon, contentDescription = null, tint = space.accent.readable(), modifier = Modifier.size(25.dp))
                            Spacer(Modifier.height(7.dp))
                            Text(space.label, style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun AssistantBriefing(state: AssistantUiState, showConversationText: Boolean) {
    if (state.progress.isNotBlank()) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.MoreHoriz, contentDescription = null, modifier = Modifier.size(15.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(
                state.progress,
                style = MaterialTheme.typography.bodySmall,
                fontStyle = FontStyle.Italic,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Spacer(Modifier.height(8.dp))
    }
    if (!showConversationText || (state.transcript.isBlank() && state.reply.isBlank())) {
        Text(
            text = state.primaryMessage,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
        )
    } else {
        Text(state.primaryMessage, style = MaterialTheme.typography.labelMedium, color = Signal)
        if (state.transcript.isNotBlank()) {
            Spacer(Modifier.height(6.dp))
            Text("YOU", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(
                state.transcript,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (state.reply.isNotBlank()) {
            Spacer(Modifier.height(10.dp))
            Text("ASSISTANT", style = MaterialTheme.typography.labelSmall, color = Signal)
            Text(
                state.reply,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
        } else {
            Spacer(Modifier.height(6.dp))
            Text(
                state.secondaryMessage,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun SpaceControl(space: DashboardSpace, onClick: (DashboardSpace) -> Unit, size: Dp, modifier: Modifier) {
    Column(
        modifier = modifier.widthIn(min = size),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Surface(
            modifier = Modifier
                .size(size)
                .clip(RoundedCornerShape(22.dp))
                .clickable(role = Role.Button) { onClick(space) }
                .semantics { contentDescription = "Open ${space.label}" },
            shape = RoundedCornerShape(22.dp),
            color = space.accent.copy(alpha = 0.12f),
            border = CardDefaults.outlinedCardBorder().copy(brush = androidx.compose.ui.graphics.SolidColor(space.accent.copy(alpha = 0.4f))),
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(space.icon, null, tint = space.accent.readable(), modifier = Modifier.size(27.dp))
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(
            space.label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onBackground,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun AssistantOrb(presence: AgentPresence, onTap: () -> Unit, diameter: Dp) {
    val transition = rememberInfiniteTransition(label = "orb")
    var hasArrived by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { hasArrived = true }
    val arrival by animateFloatAsState(
        targetValue = if (hasArrived) 1f else 0.82f,
        animationSpec = spring(dampingRatio = 0.72f, stiffness = 240f),
        label = "arrival bloom",
    )
    val listeningPulse by transition.animateFloat(0.94f, 1.06f, infiniteRepeatable(tween(920, easing = FastOutSlowInEasing), RepeatMode.Reverse), "listening radar")
    val thinkingRotation by transition.animateFloat(0f, 360f, infiniteRepeatable(tween(3400, easing = FastOutSlowInEasing)), "thinking orbit")
    val speakingPulse by transition.animateFloat(0.82f, 1.18f, infiniteRepeatable(tween(310, easing = FastOutSlowInEasing), RepeatMode.Reverse), "speaking waveform")
    val coreScale = arrival * when (presence) {
        AgentPresence.LISTENING -> listeningPulse
        AgentPresence.THINKING -> 0.98f
        AgentPresence.SPEAKING -> 1.03f
        else -> 1f
    }
    val isActive = presence in setOf(AgentPresence.PREPARING, AgentPresence.LISTENING, AgentPresence.THINKING, AgentPresence.SPEAKING)
    Box(
        modifier = Modifier
            .size(diameter)
            .scale(coreScale)
            .clip(CircleShape)
            .clickable(role = Role.Button, onClick = onTap)
            .border(1.dp, Signal.copy(alpha = 0.56f), CircleShape)
            .background(Signal.copy(alpha = if (isActive) 0.2f else 0.1f), CircleShape)
            .semantics { contentDescription = presence.accessibilityDescription },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(diameter * 0.70f).rotate(28f + if (presence == AgentPresence.THINKING) thinkingRotation else 0f).border(1.dp, Signal.copy(alpha = 0.70f), RoundedCornerShape(30.dp)))
        Box(Modifier.size(diameter * 0.56f).rotate(63f - if (presence == AgentPresence.THINKING) thinkingRotation * 0.55f else 0f).border(1.dp, Signal.copy(alpha = 0.38f), RoundedCornerShape(26.dp)))
        Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
            repeat(5) { index ->
                val height = when (presence) {
                    AgentPresence.LISTENING -> (12 + (index % 3) * 10).dp * listeningPulse
                    AgentPresence.THINKING -> (8 + if (index == 2) 14 else (index % 2) * 5).dp
                    AgentPresence.SPEAKING -> (10 + (if (index % 2 == 0) 16 else 27) * speakingPulse).dp
                    AgentPresence.PREPARING -> (7 + (index % 3) * 6).dp
                    else -> 6.dp
                }
                Box(Modifier.width(4.dp).height(height).background(Signal, CircleShape))
            }
        }
    }
}

private val AgentPresence.accessibilityDescription: String
    get() = when (this) {
        AgentPresence.LISTENING -> "Mission Control is listening. Tap to end the conversation."
        AgentPresence.THINKING -> "Mission Control is thinking. Tap to end the conversation."
        AgentPresence.SPEAKING -> "Mission Control is speaking. Tap to interrupt."
        AgentPresence.PREPARING -> "Mission Control is waking."
        AgentPresence.UNAVAILABLE -> "Mission Control is unavailable. Tap to try again."
        AgentPresence.IDLE -> "Mission Control. Tap to speak."
    }

@Composable
private fun AttentionRail(items: List<AttentionItem>, modifier: Modifier = Modifier) {
    Surface(modifier = modifier, color = MaterialTheme.colorScheme.surface.copy(alpha = 0.86f), shape = RoundedCornerShape(16.dp), tonalElevation = 0.dp, border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline)) {
        Row(modifier = Modifier.padding(14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            items.forEach { item ->
                Column(modifier = Modifier.weight(1f)) {
                    Text(item.time, style = MaterialTheme.typography.labelSmall, color = item.accent.readable(), fontWeight = FontWeight.Bold)
                    Text(item.title, style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(item.detail, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun SpaceDialog(space: DashboardSpace, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        AnimatedVisibility(
            visible = true,
            enter = fadeIn() + scaleIn(initialScale = 0.92f),
            exit = fadeOut() + scaleOut(targetScale = 0.92f),
        ) {
            Surface(
                modifier = Modifier.fillMaxWidth(0.9f).fillMaxHeight(0.9f),
                shape = RoundedCornerShape(24.dp),
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 8.dp,
            ) {
                Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(shape = RoundedCornerShape(16.dp), color = space.accent.copy(alpha = 0.14f)) {
                            Icon(space.icon, null, tint = space.accent.readable(), modifier = Modifier.padding(12.dp).size(28.dp))
                        }
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            Text(space.label, style = MaterialTheme.typography.headlineMedium)
                            Text(space.summary, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        IconButton(onClick = onDismiss) { Icon(Icons.Outlined.Close, "Close ${space.label}") }
                    }
                    Spacer(Modifier.height(24.dp))
                    HorizontalDivider(color = GraphiteLine.copy(alpha = 0.7f))
                    Spacer(Modifier.height(20.dp))
                    Text("Ready when you are", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    Text("This Android view is intentionally a calm overview. Live data, scanning, and assistant actions will connect through the shared backend rather than being duplicated locally.", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.weight(1f))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        DialogAction(Icons.Outlined.Add, "Add")
                        DialogAction(Icons.Outlined.CameraAlt, "Capture")
                        DialogAction(Icons.Outlined.AttachFile, "Attach")
                        DialogAction(Icons.Outlined.NearMe, "Open detail")
                    }
                }
            }
        }
    }
}

@Composable
private fun RowScope.DialogAction(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String) {
    Surface(
        modifier = Modifier.weight(1f).height(64.dp),
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Icon(icon, null, modifier = Modifier.size(20.dp), tint = MaterialTheme.colorScheme.primary)
            Text(label, style = MaterialTheme.typography.labelSmall)
        }
    }
}
