import { Mail } from 'lucide-react'
import { InfoLayout } from '../features/landing/InfoLayout'

const CONTACT_EMAIL = 'abishekkumar92@gmail.com'

const HELP: [string, string][] = [
  ['I can’t sign in', 'Mission Control signs in through Clerk, including with Google. Check your connection and try again. If it keeps failing, email us the time it happened and we will look into it.'],
  ['The assistant doesn’t reply to my voice', 'Allow the microphone and speech access when asked (Settings ▸ Mission Control). Your words are transcribed on your iPhone; the first use downloads the Apple language model it needs, which can take a moment.'],
  ['My calendar events don’t show', 'Mission Control shows today’s events next to your plan only if you allow calendar access. Turn it on in Settings ▸ Mission Control ▸ Calendars. Events stay on your device.'],
  ['I’m not getting reminders', 'Allow notifications in Settings ▸ Mission Control ▸ Notifications, and check that the reminder has a time. Focus modes can also silence them.'],
  ['The app says it can’t reach my workspace', 'Check your connection, then reopen the app. If your workspace is still being set up after sign-up, wait a minute and try again.'],
]

export default function Support() {
  return (
    <InfoLayout
      title="Support"
      description="Get help with Mission Control: contact us, fix common problems, and ask for your data to be exported or deleted."
    >
      <header className="lp-info-head">
        <h1>How can we help?</h1>
        <p>Write to us and a person will reply. Most questions are answered within a few days.</p>
      </header>

      <section className="lp-info-section" data-info-reveal>
        <h2>Contact</h2>
        <p>
          <Mail size={16} aria-hidden="true" style={{ verticalAlign: '-3px', marginRight: 8 }} />
          <a href={`mailto:${CONTACT_EMAIL}?subject=Mission%20Control%20support`}>{CONTACT_EMAIL}</a>
        </p>
        <p>Please include your iPhone model, iOS version and what you were doing. Never send passwords.</p>
      </section>

      <section className="lp-info-section" data-info-reveal>
        <h2>Your data</h2>
        <p>
          To export or delete your account and everything stored in your workspace, email us from the address you signed
          in with. We delete within 30 days. See the <a href="/privacy#policy">Privacy Policy</a>.
        </p>
      </section>

      <section className="lp-info-section" data-info-reveal>
        <h2>Common questions</h2>
        {HELP.map(([q, a]) => (
          <details key={q}>
            <summary>{q}</summary>
            <p>{a}</p>
          </details>
        ))}
      </section>
    </InfoLayout>
  )
}
