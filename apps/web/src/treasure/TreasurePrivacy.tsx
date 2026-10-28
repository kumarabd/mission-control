import { Link } from 'react-router-dom'
import { CONTACT_EMAIL, OPERATOR, usePageTitle } from './site'

export default function TreasurePrivacy() {
  usePageTitle('Treasure privacy policy', 'How Treasure handles your information: what stays on your device, what is saved to your account, and your choices.')
  return (
    <section className="tr-doc">
      <div className="wrap">
        <span className="eyebrow" data-reveal>Privacy Policy</span>
        <h1 data-reveal>Your money is your business.</h1>
        <p className="meta" data-reveal>Effective 5 October 2026 · Treasure for iPhone</p>

        <div className="tr-callout" data-reveal>
          <p>In short: Treasure reads your receipts and statements on your iPhone and does not upload the files. Only the transactions you review and confirm are saved to your account. We do not sell your data, show ads, or track you across other apps and websites.</p>
        </div>

        <h2>Who we are</h2>
        <p>Treasure is operated by {OPERATOR} (&ldquo;we&rdquo;, &ldquo;us&rdquo;). You can reach us at <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>.</p>

        <h2>What we collect</h2>
        <ul>
          <li><b>Account details.</b> When you sign in with Google, we receive your email address and name from our sign-in provider, Clerk, so we can recognise your account.</li>
          <li><b>Financial records you save.</b> The transactions you add or confirm: date, amount, currency, merchant, description, category, tags, notes, an account label, and links such as a refund&rsquo;s original purchase. This is the information the app exists to hold.</li>
          <li><b>Document references.</b> When you import a file, we save a reference to it (a title, a file fingerprint and a note) so a spend can point back to its source. The file or photo itself is not stored on our servers.</li>
          <li><b>Operational logs.</b> Our servers keep standard logs such as request time, error codes and IP address, to keep the service secure and working.</li>
        </ul>

        <h2>What stays on your device</h2>
        <p>Photos, scans, PDFs and CSV files you import are read on your iPhone using the text recognition and document tools built into iOS. They are not sent to us or to any third-party reading service. Face ID or your passcode, if you turn on the lock, is handled entirely by iOS; we never receive biometric data.</p>
        <p>The app also keeps a local copy of your recent spends so it works offline, and holds spends you add without a connection until they can be sent.</p>

        <h2>How we use information</h2>
        <ul>
          <li>To show you your spending, categories, trends and exports.</li>
          <li>To sign you in and keep your data separate from everyone else&rsquo;s.</li>
          <li>To keep the service secure, fix problems and answer your support requests.</li>
        </ul>
        <p>We do not use your financial records for advertising, profiling or to train models.</p>

        <h2>Who we share it with</h2>
        <p>We do not sell or rent your information. We rely on a small number of service providers to run Treasure: Clerk (sign-in), Google (if you choose Google sign-in) and our hosting infrastructure. They process data only to provide those services. We may disclose information if the law requires it.</p>

        <h2>Tracking</h2>
        <p>Treasure contains no advertising, no analytics or tracking SDKs, and does not track you across other companies&rsquo; apps and websites.</p>

        <h2>How long we keep it</h2>
        <p>We keep your records until you delete them or delete your account. Spends you delete in the app can be restored for a time and are then removed. When you ask us to delete your account, we delete your account and all of its financial records and document references.</p>

        <h2>Your choices</h2>
        <ul>
          <li><b>Access and export.</b> Export your spends as a CSV from the app at any time.</li>
          <li><b>Correct.</b> Edit or delete any spend, category, tag or merchant in the app.</li>
          <li><b>Delete.</b> Email <a href={`mailto:${CONTACT_EMAIL}?subject=Delete%20my%20Treasure%20account`}>{CONTACT_EMAIL}</a> from the address you signed in with. In-app deletion is coming.</li>
          <li>Depending on where you live, you may have further rights over your information, such as objecting to or restricting its use. Write to us and we will help.</li>
        </ul>

        <h2>Security</h2>
        <p>Data travels over encrypted connections. Each account&rsquo;s records are stored separately and only reachable with that account&rsquo;s sign-in. No system is perfectly secure, so we also encourage you to use the Face ID lock and keep your device up to date.</p>

        <h2>Children</h2>
        <p>Treasure is not directed at children under 13 and we do not knowingly collect their information.</p>

        <h2>Changes</h2>
        <p>If we change this policy in a meaningful way, we will update the date above and, where appropriate, tell you in the app.</p>

        <h2>Contact</h2>
        <p>Questions about privacy? Email <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> or visit <Link to="/treasure/support">Support</Link>.</p>
      </div>
    </section>
  )
}
