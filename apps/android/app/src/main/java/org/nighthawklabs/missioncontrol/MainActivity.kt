package org.nighthawklabs.missioncontrol

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import org.nighthawklabs.missioncontrol.ui.theme.MissionControlTheme
import org.nighthawklabs.missioncontrol.feature.dashboard.DashboardScreen
import org.nighthawklabs.missioncontrol.feature.dashboard.DashboardViewModel

class MainActivity : ComponentActivity() {
    private val dashboardViewModel: DashboardViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MissionControlTheme {
                DashboardScreen(viewModel = dashboardViewModel, modifier = Modifier.fillMaxSize())
            }
        }
    }

    override fun onStart() {
        super.onStart()
        dashboardViewModel.setAppForeground(true)
    }

    override fun onStop() {
        dashboardViewModel.setAppForeground(false)
        super.onStop()
    }
}
