import { Link } from 'react-router-dom'
import { Download, Mail, ShieldCheck, Trash2 } from 'lucide-react'
import { CONTACT_EMAIL, usePageTitle } from './site'

const HELP: [string, string][] = [
  ['I can\'t sign in', 'Treasure signs in with Google. Check your connection, then try again. If it keeps failing, email us the time it happened and we will look into it.'],
  ['An import found the wrong amounts', 'On the review screen, check the currency, and for statements open "Money in and out look swapped?" to flip the sign. You can also uncheck any row or change its type and category before importing.'],
  ['A card payment is counted as spending', 'Open the spend, change its type to Transfer, and it leaves your totals. Importing the other account\'s statement lets Treasure match the two sides automatically.'],
  ['My spends are missing', 'Pull down on Overview or Spends to refresh. Spends added offline appear under "Waiting to sync" and are sent when you are back online.'],
  ['The numbers look different from my bank', 'Treasure counts expenses minus refunds. Payments and transfers between your own accounts are left out, and deposits are not tracked as income.'],
]

export default function TreasureSupport() {
  usePageTitle('Treasure support', 'Get help with Treasure: contact us, fix common problems, export or delete your data.')
  return (
    <section className="tr-doc">
      <div className="wrap">
        <span className="eyebrow" data-reveal>Support</span>
        <h1 data-reveal>How can we help?</h1>
        <p className="lede" data-reveal>Write to us and a person will reply. Most questions are answered within a few days.</p>

        <div className="tr-callout" data-reveal>
          <p><Mail size={18} style={{ verticalAlign: '-3px', marginRight: 8 }} /> <a href={`mailto:${CONTACT_EMAIL}?subject=Treasure%20support`}>{CONTACT_EMAIL}</a></p>
          <p style={{ marginTop: 8, fontSize: '.92rem', color: '#8a94a1' }}>Please include your iPhone model, iOS version and what you were doing. Never send passwords or full account numbers.</p>
        </div>

        <div className="tr-support-grid">
          <article className="tr-tile" data-reveal>
            <span className="tr-ico"><Download size={24} /></span>
            <h3>Export your data</h3>
            <p>In Treasure, open Spends, tap the ⋯ menu and choose Export. You get a CSV of whatever your filters show, or everything from More.</p>
          </article>
          <article className="tr-tile" data-reveal style={{ ['--d' as string]: '.08s' }}>
            <span className="tr-ico"><Trash2 size={24} /></span>
            <h3>Delete your account</h3>
            <p>Email us from the address you signed in with and we will delete your account and all spends, categories, tags and document references. In-app deletion is coming.</p>
          </article>
        </div>

        <h2 data-reveal>Common questions</h2>
        <div className="tr-faq" data-reveal style={{ maxWidth: 'none', marginTop: 20 }}>
          {HELP.map(([q, a]) => (
            <details key={q}><summary>{q}</summary><p>{a}</p></details>
          ))}
        </div>

        <h2 data-reveal>Privacy</h2>
        <p data-reveal><ShieldCheck size={18} style={{ verticalAlign: '-3px', marginRight: 8, color: '#e3b25c' }} />Receipts and statements are read on your phone and are not uploaded. Read the full <Link to="/treasure/privacy">Privacy Policy</Link>.</p>
      </div>
    </section>
  )
}
