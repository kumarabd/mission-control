import { Link } from 'react-router-dom'
import { ArrowRight, Check, Database, KeyRound, LockKeyhole, Users } from 'lucide-react'
import { InfoLayout } from '../features/landing/InfoLayout'

export default function Privacy() {
  return (
    <InfoLayout
      title="How your data works"
      description="How Mission Control handles your data: your account workspace, model and service egress, approvals, model choice and what comes next."
    >
      <header className="lp-info-head">
        <h1>How your data works.</h1>
        <p>Short version: your account has its own workspace. You choose what it can reach, and you can see what leaves.</p>
      </header>

      <div className="lp-status-legend" aria-label="Status labels used on this page">
        <span className="lp-status lp-status-now">Available now</span>
        <span className="lp-status lp-status-dev">In development</span>
        <span className="lp-status lp-status-next">Next</span>
      </div>

      <section className="lp-info-section" data-info-reveal>
        <h2>Inside your workspace</h2>
        <p>
          Your account is provisioned with its own data services, database and persistent storage. Some platform
          infrastructure — authentication, routing and a shared orchestration pool — is shared across accounts.
          Account isolation is not the same as an independent computer or end-to-end encryption.
        </p>
        <div className="lp-info-grid">
          <article className="lp-info-card">
            <Database size={18} aria-hidden="true" />
            <h3>Your account space</h3>
            <p>Dedicated data services and storage for your account, reached through authenticated routing.</p>
            <span className="lp-status lp-status-now">Available now</span>
          </article>
          <article className="lp-info-card">
            <Users size={18} aria-hidden="true" />
            <h3>Companions and memory banks</h3>
            <p>Named companions with separate instructions and memory banks inside the same workspace.</p>
            <span className="lp-status lp-status-now">Available now</span>
          </article>
          <article className="lp-info-card">
            <LockKeyhole size={18} aria-hidden="true" />
            <h3>Independent environments</h3>
            <p>Stronger separation for each companion, beyond the current shared workspace services.</p>
            <span className="lp-status lp-status-next">Next</span>
          </article>
          <article className="lp-info-card">
            <KeyRound size={18} aria-hidden="true" />
            <h3>Customer-managed keys</h3>
            <p>Key lifecycle controls and stronger end-to-end protections are intended directions, not current features.</p>
            <span className="lp-status lp-status-next">Next</span>
          </article>
        </div>
      </section>

      <section className="lp-info-section" data-info-reveal>
        <h2>What leaves your space</h2>
        <p>
          When a companion uses an AI model, the context needed for that request goes to the configured provider or
          endpoint. Connected services receive the requests made to them. Shared orchestration metadata and
          operational services have their own roles.
        </p>
        <div className="lp-info-route">
          <i className="lp-info-route-line" aria-hidden="true" />
          <i className="lp-info-route-packet" aria-hidden="true" />
          <span className="lp-route-chip">Your workspace</span>
          <ArrowRight className="lp-info-route-arrow" size={14} aria-hidden="true" />
          <span className="lp-route-chip">Model provider</span>
          <span className="lp-route-chip">Connected services</span>
        </div>
        <div className="lp-info-callout">
          <strong>No end-to-end claim.</strong> We do not currently claim end-to-end encryption or operator-blind
          access. A model API key is not an encryption key; it does not make inference private from the provider or
          the platform runtime.
        </div>
      </section>

      <section className="lp-info-section" data-info-reveal>
        <h2>What you control</h2>
        <ul className="lp-info-list">
          <li><Check size={15} aria-hidden="true" /> Inspect supported memory and activity views, including recorded sources where available.</li>
          <li><Check size={15} aria-hidden="true" /> Choose which accounts and tools your companion can use.</li>
          <li><Check size={15} aria-hidden="true" /> Respond to configured approval requests. Approval coverage depends on the tools and policies in use.</li>
          <li><Check size={15} aria-hidden="true" /> Use platform models, or configure a supported provider or endpoint with your own credentials.</li>
        </ul>
      </section>

      <section className="lp-info-section" data-info-reveal>
        <h2>What’s next</h2>
        <p>
          Customer-managed encryption keys, stronger end-to-end protections, independent environments per companion,
          clearer data-lifecycle controls and access from more devices. These are directions, not current features,
          and no release dates are promised.
        </p>
      </section>

      <div className="lp-info-links">
        <Link to="/docs/architecture/isolation">Technical isolation notes <ArrowRight size={16} aria-hidden="true" /></Link>
        <Link to="/capabilities">What’s available <ArrowRight size={16} aria-hidden="true" /></Link>
      </div>

      <section className="lp-info-section" id="policy" data-info-reveal>
        <h2>Privacy Policy</h2>
        <p>Last updated: October 19, 2026. Mission Control (“we”, “us”) is operated by Nighthawk Labs at mission-control.nighthawklabs.org.</p>

        <h3>Information we collect</h3>
        <ul className="lp-info-list">
          <li><Check size={15} aria-hidden="true" /> <strong>Account information.</strong> When you sign in, including with Google, we receive your name, email address and profile photo through our authentication provider (Clerk).</li>
          <li><Check size={15} aria-hidden="true" /> <strong>Content you give your companion.</strong> Messages, goals, reminders, memories and files you add, stored in your account’s workspace.</li>
          <li><Check size={15} aria-hidden="true" /> <strong>Data from services you connect.</strong> Only if you choose to connect a service (for example a Google account), and only the data your companion needs to act on your requests.</li>
          <li><Check size={15} aria-hidden="true" /> <strong>iPhone app permissions.</strong> If you allow them: the microphone (speech is transcribed on your device, and only the text is sent), the camera (to scan text or codes, or read a photo you choose), calendar (today’s events are shown beside your plan and stay on your device), Apple Health read access (to show your own summary on your device), and notifications (reminders and assistant messages). You can turn each off in iOS Settings.</li>
          <li><Check size={15} aria-hidden="true" /> <strong>Technical data.</strong> Basic logs such as IP address, device and browser type, used to keep the service running and secure.</li>
        </ul>

        <h3>How we use it</h3>
        <p>
          To authenticate you, run your companion and its memory, perform the actions you ask for, provide support, and
          keep the service secure. We do not sell your data and we do not use it for advertising.
        </p>

        <h3>Google user data</h3>
        <p>
          Mission Control’s use and transfer of information received from Google APIs adheres to the{' '}
          <a href="https://developers.google.com/terms/api-services-user-data-policy#limited-use" target="_blank" rel="noreferrer">Google API Services User Data Policy</a>,
          including the Limited Use requirements. Google user data is used only to provide the user-facing features you
          requested, is not transferred to others except to provide those features, comply with law, or as part of a
          merger or sale with notice to you, is not used for advertising, and is not read by humans unless you ask for
          support, it is needed for security or abuse investigation, or the law requires it. It is not used to develop or
          train generalized AI or machine-learning models.
        </p>

        <h3>Gmail data</h3>
        <p>
          If you connect Gmail, we request read access (gmail.readonly) and draft-creation access (gmail.compose).
          Your companion uses them to search and read your email threads, manage labels, and create drafts when you ask.
          It does not send email on your behalf. Message content is processed to answer your request and is not stored
          beyond what you ask your companion to remember. You can disconnect Gmail at any time.
        </p>

        <h3>Sharing</h3>
        <p>
          We share data only with processors needed to run the service: authentication (Clerk), hosting and
          infrastructure, and the AI model provider you or the platform configures, which receives the context needed
          for each request (see “What leaves your space” above). We may disclose data if required by law.
        </p>

        <h3>Retention and deletion</h3>
        <p>
          We keep your data while your account is active. You can disconnect any connected service at any time, which
          revokes our access (you can also revoke it at myaccount.google.com/permissions). To delete your account and
          its data, email us and we will delete it within 30 days.
        </p>

        <h3>Security</h3>
        <p>Data is encrypted in transit and access is authenticated. As described above, we do not claim end-to-end encryption.</p>

        <h3>Children</h3>
        <p>Mission Control is not directed to children under 13 and we do not knowingly collect their data.</p>

        <h3>Changes and contact</h3>
        <p>
          We will post changes on this page and update the date above. Questions or deletion requests:{' '}
          <a href="mailto:abishekkumar92@gmail.com">abishekkumar92@gmail.com</a>.
        </p>
      </section>
    </InfoLayout>
  )
}
