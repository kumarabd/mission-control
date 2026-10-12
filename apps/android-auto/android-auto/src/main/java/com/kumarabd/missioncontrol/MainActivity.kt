package com.kumarabd.missioncontrol

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import com.clerk.api.Clerk
import com.clerk.api.network.serialization.successOrNull
import com.kumarabd.missioncontrol.media.BriefingGateway
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * The phone surface deliberately stays minimal. Account setup, settings, and
 * anything that needs a long response remain off the in-car display.
 */
class MainActivity : ComponentActivity() {
    private lateinit var status: TextView
    private lateinit var email: EditText
    private lateinit var password: EditText
    private lateinit var signIn: Button
    private lateinit var refresh: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val padding = (24 * resources.displayMetrics.density).toInt()
        status = TextView(this).apply { textSize = 18f }
        email = EditText(this).apply { hint = "Email" }
        password = EditText(this).apply {
            hint = "Password"
            inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD
        }
        signIn = Button(this).apply {
            text = "Sign in"
            setOnClickListener { beginSignIn() }
        }
        refresh = Button(this).apply {
            text = "Refresh briefings"
            setOnClickListener { refreshBriefings() }
        }
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
            addView(status)
            addView(email)
            addView(password)
            addView(signIn)
            addView(refresh)
        })

        lifecycleScope.launch {
            Clerk.isInitialized.filter { it }.first()
            updateSignedInState()
        }
    }

    private fun beginSignIn() = lifecycleScope.launch {
        val identifier = email.text.toString().trim()
        val secret = password.text.toString()
        if (identifier.isBlank() || secret.isBlank()) {
            status.text = "Enter your email and password to sign in."
            return@launch
        }
        status.text = "Signing in…"
        val signIn = Clerk.auth.signInWithPassword {
            this.identifier = identifier
            this.password = secret
        }.successOrNull()
        val sessionId = signIn?.createdSessionId
        if (sessionId == null) {
            status.text = "Sign-in needs another step or could not be completed."
            return@launch
        }
        if (Clerk.auth.setActive(sessionId).successOrNull() == null) {
            status.text = "Couldn’t activate your session. Please try again."
            return@launch
        }
        password.text.clear()
        updateSignedInState()
    }

    private fun refreshBriefings() = lifecycleScope.launch {
        val token = runCatching { Clerk.auth.getToken().successOrNull() }.getOrNull()
        if (token.isNullOrBlank()) {
            status.text = "Sign in before refreshing briefings."
            return@launch
        }
        refresh.isEnabled = false
        status.text = "Refreshing briefings…"
        runCatching {
            BriefingGateway(this@MainActivity, getString(R.string.router_base_url)).refresh(token)
        }.onSuccess { count ->
            status.text = if (count == 1) "1 briefing ready for Android Auto." else "$count briefings ready for Android Auto."
        }.onFailure {
            status.text = "Couldn’t refresh briefings. Check your connection and try again."
        }
        refresh.isEnabled = true
    }

    private fun updateSignedInState() {
        val signedIn = Clerk.user != null
        signIn.isEnabled = !signedIn
        refresh.isEnabled = signedIn
        status.text = if (signedIn) {
            "Signed in. Refresh before driving to make your latest voice briefings available."
        } else {
            getString(R.string.phone_only_message)
        }
    }
}
