import { useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import { animate, createTimeline, onScroll, stagger, svg, utils } from 'animejs'
import { usePageTitle } from './site'

const still = () => typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches
const OUT = 'outExpo'
// anime.js function values receive (target, index, length); only the index is used here.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const by = <T,>(fn: (i: number) => T) => ((_t: any, i: number, _l: number) => fn(i)) as any

/** The hero scene: receipts fly into the gem, and a clean month comes out. Plays on a loop. */
function useHeroScene(root: React.RefObject<HTMLDivElement | null>) {
  useEffect(() => {
    const el = root.current
    if (!el || still()) return
    const q = (s: string) => el.querySelectorAll<SVGElement>(s)
    utils.set(q('.rc'), { opacity: 0 })
    utils.set(q('.facet'), { opacity: 0 })
    utils.set(q('.out'), { opacity: 0, translateX: -24 })
    const edges = svg.createDrawable(q('.edge'))
    const tl = createTimeline({ loop: true, loopDelay: 2600, defaults: { ease: OUT } })
    tl.add(q('.rc'), { opacity: [0, 1], translateX: [-90, 0], rotate: by((i) => [-14 + i * 6, -3 + i * 2]), duration: 900, delay: stagger(140) })
      .add(edges, { draw: ['0 0', '0 1'], duration: 1200, delay: stagger(60) }, '-=300')
      .add(q('.facet'), { opacity: [0, 1], duration: 700, delay: stagger(90) }, '-=700')
      .add(q('.rc'), { translateX: 250, translateY: by((i) => [0, -12, 12][i] ?? 0), scale: 0.15, opacity: 0, rotate: 40, duration: 900, delay: stagger(120), ease: 'inExpo' }, '+=500')
      .add(q('.gem'), { scale: [1, 1.12, 1], duration: 700 }, '-=500')
      .add(q('.out'), { opacity: [0, 1], translateX: [-24, 0], duration: 800, delay: stagger(130) }, '-=200')
      .add(q('.bar'), { scaleX: [0, 1], duration: 900, delay: stagger(130) }, '-=800')
      .add(q('.rc, .edge, .facet, .out'), { opacity: 0, duration: 600, delay: 2400, ease: 'inOutQuad' })
    // The gem breathes between loops.
    const glint = animate(q('.glint'), { opacity: [0.15, 0.9], duration: 1800, loop: true, alternate: true, delay: stagger(300), ease: 'inOutSine' })
    return () => { tl.revert(); glint.revert() }
  }, [root])
}

const RECEIPTS = [
  { y: 70, w: 118, label: 'COSTCO', amt: '64.20' },
  { y: 168, w: 130, label: 'STATEMENT', amt: '1,204.18' },
  { y: 266, w: 108, label: 'UBER', amt: '18.40' },
]
const OUTPUTS = [
  { y: 106, name: 'Groceries', amt: '$173.95', w: 150 },
  { y: 188, name: 'Dining', amt: '$48.00', w: 74 },
  { y: 270, name: 'Transport', amt: '$43.20', w: 66 },
]

function HeroScene() {
  const ref = useRef<HTMLDivElement>(null)
  useHeroScene(ref)
  return (
    <div className="tr-scene" ref={ref} role="img" aria-label="Receipts and statements go in, and a clear month comes out. Illustrative.">
      <svg viewBox="0 0 640 400" aria-hidden="true">
        <defs>
          <linearGradient id="gm-a" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#f7d796" /><stop offset="1" stopColor="#c58a22" /></linearGradient>
          <linearGradient id="gm-b" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#d6a043" /><stop offset="1" stopColor="#8a5a00" /></linearGradient>
          <linearGradient id="gm-c" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stopColor="#7a4f00" /><stop offset="1" stopColor="#e3b25c" /></linearGradient>
        </defs>
        {RECEIPTS.map((r, i) => (
          <g key={r.label} transform={`translate(24 ${r.y})`}><g className="rc" style={{ transformBox: 'fill-box', transformOrigin: 'center' }}>
            <rect width={r.w} height="74" rx="8" fill="#f2efe8" />
            <rect x="12" y="12" width="46" height="6" rx="3" fill="#b8b2a3" />
            <rect x="12" y="28" width={r.w - 40} height="4" rx="2" fill="#d3cec2" />
            <rect x="12" y="38" width={r.w - 56} height="4" rx="2" fill="#d3cec2" />
            <text x="12" y="62" fontSize="11" fontWeight="700" fill="#1b1d20" fontFamily="ui-monospace,Menlo,monospace">{r.label.slice(0, 7)} {r.amt}</text>
            {i === 1 && <path d={`M${r.w - 22} 12l6 6 10-12`} fill="none" stroke="#0a7a4c" strokeWidth="2.4" strokeLinecap="round" />}
          </g></g>
        ))}
        {/* the gem */}
        <g transform="translate(244 100) scale(1.15)"><g className="gem" style={{ transformBox: 'fill-box', transformOrigin: 'center' }}>
          <g className="float">
            <polygon className="facet" points="30,0 60,0 45,40 0,40" fill="url(#gm-b)" />
            <polygon className="facet" points="60,0 90,0 105,40 45,40" fill="url(#gm-a)" />
            <polygon className="facet" points="90,0 120,0 150,40 105,40" fill="url(#gm-b)" />
            <polygon className="facet" points="0,40 45,40 75,100" fill="url(#gm-c)" />
            <polygon className="facet" points="45,40 105,40 75,100" fill="url(#gm-a)" opacity=".92" />
            <polygon className="facet" points="105,40 150,40 75,100" fill="url(#gm-c)" />
            <path className="edge" d="M30 0 L120 0 L150 40 L75 100 L0 40 Z M0 40 L150 40 M60 0 L45 40 L75 100 M90 0 L105 40 L75 100 M45 40 L105 40" fill="none" stroke="#f7d796" strokeWidth="1.6" strokeLinejoin="round" />
            <polygon className="glint" points="64,4 84,4 92,26 58,26" fill="#fff" opacity=".4" />
            <polygon className="glint" points="104,6 114,6 124,24 108,24" fill="#fff" opacity=".3" />
          </g>
        </g></g>
        {OUTPUTS.map((o) => (
          <g key={o.name} transform={`translate(430 ${o.y})`}><g className="out">
            <text y="-8" fontSize="14" fill="#e8ecf1" fontFamily="inherit">{o.name}</text>
            <text x="180" y="-8" fontSize="14" fill="#e8ecf1" textAnchor="end" fontFamily="inherit" style={{ fontVariantNumeric: 'tabular-nums' }}>{o.amt}</text>
            <rect y="2" width="180" height="6" rx="3" fill="#262c34" />
            <rect className="bar" y="2" width={o.w} height="6" rx="3" fill="#e3b25c" style={{ transformOrigin: 'left center', transformBox: 'fill-box' }} />
          </g></g>
        ))}
      </svg>
    </div>
  )
}

/** A phone screen. Three of them stack and cross-fade as the story scrolls. */
function Screens() {
  return (
    <div className="tr-phone2" aria-hidden="true">
      <div className="notch" />
      <div className="scr s1">
        <h4>Import</h4>
        <div className="mini-note">Statement.pdf · Chase ••4821</div>
        {[['Whole Foods', '$64.20', 1], ['Uber', '$18.40', 1], ['PAYMENT THANK YOU', '$500.00', 0], ['Blue Bottle', '$4.75', 1]].map(([n, a, on]) => (
          <div className="rowx" key={n as string}><i className={on ? 'on' : 'off'} /><span>{n}</span><b>{a}</b></div>
        ))}
        <div className="mini-note ok">Counts as spending: $87.35 · 1 payment not counted</div>
      </div>
      <div className="scr s2">
        <h4>Overview</h4>
        <div className="cardx"><small>Spent in October</small><div className="amt">$319.54</div>
          <div className="bars">{[92, 38, 10, 66, 24, 48, 18, 72, 30, 14, 56, 34].map((h, i) => <i key={i} style={{ height: `${h}%` }} />)}</div>
          <div className="pace"><b /></div><small>Day 5 of 31 · On pace for $1,982</small></div>
        <div className="cardx"><small>Where it went</small>
          {[['Groceries', '$173.95', 70], ['Dining', '$48.00', 34], ['Transport', '$43.20', 30]].map(([n, a, w]) => (
            <div className="catx" key={n as string}><span>{n}</span><b>{a}</b><i style={{ width: `${w}%` }} /></div>
          ))}</div>
      </div>
      <div className="scr s3">
        <h4>Insights</h4>
        <div className="seg"><span>Week</span><span className="on">Month</span><span>Year</span></div>
        <div className="nav3">‹ <b>September 2026</b> ›</div>
        <div className="cardx big"><div className="bars tall">{[40, 62, 28, 80, 50, 34, 90, 44, 58, 26, 70, 36, 52, 30].map((h, i) => <i key={i} style={{ height: `${h}%` }} />)}</div></div>
        <div className="cardx"><div className="catx"><span>Groceries</span><b>$412.80</b><i style={{ width: '82%' }} /></div><div className="catx"><span>Dining</span><b>$198.00</b><i style={{ width: '48%' }} /></div></div>
      </div>
    </div>
  )
}

const STORY = [
  { h: 'Drop it in.', p: 'Photograph a receipt, scan a document, or choose PDFs and bank CSVs. Treasure reads them on your phone, spots the account, and flags what you already have.' },
  { h: 'See the month.', p: 'Spending so far, the pace you are on, and where it went. Payments between your own accounts are left out, so the total is honest.' },
  { h: 'Go back in time.', p: 'Step through months, compare with the period before, and tap any category to see the spends behind it.' },
]

function StorySection() {
  const sec = useRef<HTMLElement>(null)
  useEffect(() => {
    const el = sec.current
    if (!el || still()) return
    const q = (s: string) => el.querySelectorAll<HTMLElement>(s)
    utils.set(q('.s2, .s3'), { opacity: 0, translateY: 24 })
    utils.set(q('.story-text li:not(:first-child)'), { opacity: 0.25 })
    const tl = createTimeline({
      defaults: { ease: 'linear', duration: 260 },
      autoplay: onScroll({ target: el, enter: 'top top', leave: 'bottom bottom', sync: 0.3 }),
    })
    tl.add(q('.s1'), { opacity: 0, translateY: -24 }, 1000)
      .add(q('.s2'), { opacity: [0, 1], translateY: [24, 0] }, 1000)
      .add(q('.story-text li:nth-child(1)'), { opacity: 0.25 }, 1000)
      .add(q('.story-text li:nth-child(2)'), { opacity: [0.25, 1] }, 1000)
      .add(q('.s2 .bars i'), { scaleY: [0.1, 1], delay: stagger(25) }, 1000)
      .add(q('.s2'), { opacity: 0, translateY: -24 }, 2000)
      .add(q('.s3'), { opacity: [0, 1], translateY: [24, 0] }, 2000)
      .add(q('.story-text li:nth-child(2)'), { opacity: 0.25 }, 2000)
      .add(q('.story-text li:nth-child(3)'), { opacity: [0.25, 1] }, 2000)
      .add(q('.s3 .bars i'), { scaleY: [0.1, 1], delay: stagger(25) }, 2000)
      .add(q('.gem-spin'), { rotate: 120 }, 0)
    return () => { tl.revert() }
  }, [])
  return (
    <section className="tr-story" ref={sec} aria-label="How Treasure works">
      <div className="tr-sticky">
        <div className="wrap tr-story-grid">
          <ol className="story-text">
            {STORY.map((s) => (
              <li key={s.h}><h2>{s.h}</h2><p>{s.p}</p></li>
            ))}
          </ol>
          <div className="tr-story-stage">
            <svg className="gem-spin" viewBox="0 0 200 200" aria-hidden="true"><rect x="40" y="40" width="120" height="120" rx="18" /></svg>
            <svg className="gem-spin two" viewBox="0 0 200 200" aria-hidden="true"><circle cx="100" cy="100" r="96" /></svg>
            <Screens />
          </div>
        </div>
      </div>
    </section>
  )
}

/** The proof: a card payment leaves the bank and arrives on the card; together they are not spending. */
function TransferProof() {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const q = (s: string) => el.querySelectorAll<HTMLElement>(s)
    const total = el.querySelector<HTMLElement>('.sum b')
    if (still()) { if (total) total.textContent = '$0.00'; return }
    utils.set(q('.l1'), { translateX: -60, opacity: 0 })
    utils.set(q('.l2'), { translateX: 60, opacity: 0 })
    utils.set(q('.sum'), { opacity: 0, translateY: 14 })
    utils.set(q('.link'), { scaleX: 0 })
    const counter = { v: 500 }
    const tl = createTimeline({
      autoplay: onScroll({ target: el, enter: 'bottom-=15% top', leave: 'top bottom', repeat: false, onEnter: () => tl.play() }),
      defaults: { ease: OUT },
    })
    tl.add(q('.l1'), { translateX: 0, opacity: 1, duration: 800 })
      .add(q('.l2'), { translateX: 0, opacity: 1, duration: 800 }, '-=600')
      .add(q('.link'), { scaleX: 1, duration: 700 }, '-=200')
      .add(q('.l1, .l2'), { opacity: 0.45, duration: 500 }, '+=200')
      .add(q('.sum'), { opacity: 1, translateY: 0, duration: 600 }, '-=300')
      .add(counter, { v: 0, duration: 900, ease: 'outCubic', onUpdate: () => { if (total) total.textContent = `$${counter.v.toFixed(2)}` } }, '-=500')
    tl.pause()
    return () => { tl.revert() }
  }, [])
  return (
    <div className="tr-proof" ref={ref}>
      <div className="line l1"><span>Acme Bank</span><i>Card payment</i><b className="neg">−$500.00</b></div>
      <div className="link" aria-hidden="true" />
      <div className="line l2"><span>Chase ••4821</span><i>Payment received</i><b className="pos">+$500.00</b></div>
      <div className="sum"><span>Counted as spending</span><b>$500.00</b></div>
    </div>
  )
}

const FEATURES = [
  ['Split a purchase', 'Divide one receipt across categories. Treasure checks that it adds up before you save.'],
  ['Link a refund', 'Tie a refund to the purchase it belongs to and see the net after refunds.'],
  ['Your structure', 'Categories, tags and merchants you control. Merge, rename, restore.'],
  ['Edit in bulk', 'Select many spends and recategorise, tag or delete in one move, with undo.'],
  ['Works offline', 'Add spends anywhere. They send themselves when you are back.'],
  ['Face ID lock', 'Treasure opens only for you.'],
]

const FAQ = [
  ['Does Treasure connect to my bank?', 'No. You bring in the receipts, statements and CSV exports you choose. Treasure never asks for your bank login.'],
  ['Where are my receipts and statements stored?', 'Files and photos are read on your iPhone and are not uploaded. Only the transactions you confirm are saved to your Treasure account.'],
  ['Why is a card payment not counted as spending?', 'Paying your card from your bank moves money between your own accounts. The purchases were already counted when you made them, so Treasure records the payment as a transfer and leaves it out of the totals.'],
  ['Can I use it offline?', 'Yes. Spends you add offline are kept on the phone and sent when you are back online.'],
  ['Is there an Android version?', 'An Android version is in development. Treasure for iPhone comes first.'],
  ['How do I delete my data?', 'Email support from the Support page and your account and its data will be deleted. In-app deletion is coming.'],
]

export default function TreasureLanding() {
  usePageTitle('Treasure: see where your money goes', 'Treasure reads your receipts and statements on your iPhone and shows where your money goes. Private by design.')
  const page = useRef<HTMLDivElement>(null)

  // Entrance for the headline, and slow parallax on the ambient shapes. Everything else animates in its own section.
  useEffect(() => {
    const el = page.current
    if (!el || still()) return
    const q = (s: string) => el.querySelectorAll<HTMLElement>(s)
    const intro = createTimeline({ defaults: { ease: OUT } })
    utils.set(q('.hero-word span'), { translateY: '110%' })
    utils.set(q('.hero-fade'), { opacity: 0, translateY: 18 })
    intro.add(q('.hero-word span'), { translateY: ['110%', '0%'], duration: 1100, delay: stagger(70) })
      .add(q('.hero-fade'), { opacity: [0, 1], translateY: [18, 0], duration: 900, delay: stagger(110) }, '-=700')
    const drift = animate(q('.shape-drift'), { translateY: [0, -26], rotate: by((i) => (i % 2 ? -8 : 8)), duration: 5200, loop: true, alternate: true, ease: 'inOutSine', delay: stagger(600) })
    const par = animate(q('.shape-par'), { translateY: by((i) => [0, (i % 2 ? -1 : 1) * 160]), ease: 'linear', autoplay: onScroll({ target: el, enter: 'top top', leave: 'bottom bottom', sync: 0.4 }) })
    // Feature rows rise in as they arrive.
    const rows = animate(q('.feat'), { opacity: [0, 1], translateY: [28, 0], duration: 800, delay: stagger(90), ease: OUT, autoplay: onScroll({ target: q('.tr-feats')[0], enter: 'bottom-=10% top', repeat: false }) })
    utils.set(q('.feat'), { opacity: 0 })
    const priv = animate(q('.priv-line'), { opacity: [0, 1], translateY: [24, 0], duration: 900, delay: stagger(140), ease: OUT, autoplay: onScroll({ target: q('.tr-private')[0], enter: 'bottom-=15% top', repeat: false }) })
    utils.set(q('.priv-line'), { opacity: 0 })
    return () => { intro.revert(); drift.revert(); par.revert(); rows.revert(); priv.revert() }
  }, [])

  return (
    <div ref={page}>
      <section className="tr-hero2">
        <div className="shape-drift tr-diamond d1" aria-hidden="true" />
        <div className="shape-drift tr-ring2 r1" aria-hidden="true" />
        <div className="wrap hero-grid">
          <div className="hero-copy">
            <h1 aria-label="Treasure">
              {'Treasure'.split('').map((c, i) => <span className="hero-word" key={i}><span>{c}</span></span>)}
            </h1>
            <p className="hero-tag hero-fade">See where your money goes.</p>
            <p className="hero-sub hero-fade">Bring in receipts and statements. Treasure reads them on your iPhone and turns them into a clear month, with payments between your own accounts kept out of the total.</p>
            <div className="tr-cta hero-fade">
              <span className="tr-btn primary" role="link" aria-disabled="true">Coming to the App Store</span>
              <Link className="tr-btn" to="/treasure/support">Talk to us</Link>
            </div>
          </div>
          <HeroScene />
        </div>
        <div className="tr-ticker" aria-hidden="true"><div>{[0, 1].flatMap((k) => ['Receipts', 'Bank statements', 'Card statements', 'PDFs', 'Photos', 'CSV exports', 'Refunds', 'Transfers'].map((t) => <span key={`${k}${t}`}>{t}</span>))}</div></div>
      </section>

      <StorySection />

      <section className="tr-proofsec">
        <div className="shape-par tr-diamond d2" aria-hidden="true" />
        <div className="wrap proof-grid">
          <div>
            <h2>Paying your card is not spending.</h2>
            <p className="lede">The bank shows money going out. The card shows money coming in. Treasure sees both are the same move between your own accounts, and counts neither.</p>
          </div>
          <TransferProof />
        </div>
      </section>

      <section className="tr-feats">
        <div className="wrap">
          <h2>Small things, done properly.</h2>
          <ul>
            {FEATURES.map(([h, p]) => (
              <li className="feat" key={h}><h3>{h}</h3><p>{p}</p></li>
            ))}
          </ul>
        </div>
      </section>

      <section className="tr-private">
        <div className="shape-par tr-ring2 r2" aria-hidden="true" />
        <div className="wrap">
          <h2>Read on your phone.<br />Not on our servers.</h2>
          <div className="priv-cols">
            <p className="priv-line">Photos, scans and PDFs are read with the tools built into iOS and are not uploaded.</p>
            <p className="priv-line">Only the transactions you review and confirm are saved to your account.</p>
            <p className="priv-line">No ads. No tracking. Your data is never sold. <Link to="/treasure/privacy">Read the policy</Link></p>
          </div>
        </div>
      </section>

      <section className="tr-faq2">
        <div className="wrap">
          <h2>Good to know.</h2>
          <div className="tr-faq">
            {FAQ.map(([q, a]) => (<details key={q}><summary>{q}</summary><p>{a}</p></details>))}
          </div>
        </div>
      </section>

      <section className="tr-close">
        <div className="shape-drift tr-diamond d3" aria-hidden="true" />
        <div className="wrap">
          <p className="close-word" aria-hidden="true">Treasure</p>
          <div className="tr-cta" style={{ justifyContent: 'center' }}>
            <span className="tr-btn primary" role="link" aria-disabled="true">Coming to the App Store</span>
            <Link className="tr-btn" to="/treasure/support">Get support</Link>
          </div>
        </div>
      </section>
    </div>
  )
}
