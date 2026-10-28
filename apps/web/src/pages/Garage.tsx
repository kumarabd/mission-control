import { useEffect, useLayoutEffect, useRef, type ReactNode } from 'react'
import { Link, Route, Routes } from 'react-router-dom'
import { animate, createTimeline, stagger, svg } from 'animejs'
import '@fontsource-variable/bricolage-grotesque/wght.css'
import '../features/garage/garage.css'

// Shown on the support and privacy pages. Empty hides the mailto until one is set.
const SUPPORT_EMAIL = ''
const UPDATED = 'October 5, 2026'

const STEPS = [
  { img: '/garage/vin.png', alt: 'Adding a car by VIN', t: 'Add a car with its VIN.', d: 'Type the VIN and Garage fills in the make, model, year and fuel type.' },
  { img: '/garage/car.png', alt: 'A car with an OBD adapter ready to connect', t: 'Plug in an OBD adapter.', d: 'Connect any Bluetooth Low Energy OBD-II adapter right inside the app. No pairing in Settings.' },
  { img: '/garage/live.png', alt: 'The live drive screen', t: 'Watch the drive live.', d: 'Speed, RPM, coolant, throttle and fuel update as you go. Try the demo drive if you have no adapter yet.' },
  { img: '/garage/map.png', alt: 'A drive being recorded on the map', t: 'Find it again later.', d: 'Every drive is recorded on the map, saved and uploaded, so it is there when you search.' },
]
const SPAN = 1000 // timeline ms per step

const WORDS = ['Every car.', 'Every drive.', 'Kept.']
const ADAPTERS = ['Veepeak BLE+', 'vLinker BLE', 'OBDLink CX']

const wide = '(min-width: 821px) and (prefers-reduced-motion: no-preference)'

function Shell({ children }: { children: ReactNode }) {
  useEffect(() => {
    const prev = document.title
    document.title = 'Garage'
    return () => { document.title = prev }
  }, [])
  return (
    <div className="gx">
      <div className="gx-shapes" aria-hidden="true">
        <i className="gx-s gx-ring" />
        <i className="gx-s gx-blob" />
        <i className="gx-s gx-sq" />
        <i className="gx-s gx-dot" />
      </div>
      <header className="gx-nav">
        <Link to="/garage" className="gx-brand">
          <span className="gx-logo" aria-hidden="true" />
          Garage
        </Link>
        <nav>
          <Link to="/garage/support">Support</Link>
          <Link to="/garage/privacy">Privacy</Link>
        </nav>
      </header>
      {children}
      <footer className="gx-foot">
        <span>© 2026 Garage</span>
        <span>
          <Link to="/garage/support">Support</Link> · <Link to="/garage/privacy">Privacy</Link>
        </span>
      </footer>
    </div>
  )
}

/** All the motion for the landing page. Content is visible without it; this only adds to it. */
function useLandingMotion(root: React.RefObject<HTMLElement | null>) {
  useLayoutEffect(() => {
    const el = root.current
    if (!el) return
    const q = <T extends Element>(s: string) => Array.from(el.querySelectorAll<T>(s))
    const shell = el.closest<HTMLElement>('.gx')!
    const cleanups: (() => void)[] = []
    const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches

    if (!reduce) {
      // 1. The one rehearsed moment: headline lines rise out of a mask, the road draws, the phones arrive.
      const road = svg.createDrawable(q('.gx-hero-road path.gx-trail'))
      createTimeline({ defaults: { ease: 'outExpo' } })
        .add(q('.gx-ln > span'), { translateY: ['108%', '0%'], duration: 1000, delay: stagger(110) }, 0)
        .add(q('.gx-hero-fade'), { opacity: [0, 1], translateY: [16, 0], duration: 800, delay: stagger(80) }, 450)
        .add(road, { draw: ['0 0', '0 1'], duration: 1800, ease: 'inOutQuad' }, 200)
        .add(q('.gx-p1'), { opacity: [0, 1], translateY: [80, 0], rotate: [-14, -6], duration: 1200 }, 300)
        .add(q('.gx-p2'), { opacity: [0, 1], translateY: [110, 0], rotate: [12, 5], duration: 1200 }, 450)
        .add(q('.gx-chip'), { opacity: [0, 1], scale: [0.8, 1], duration: 700, delay: stagger(140) }, 1100)

      // 2. Things that arrive once, when they are first seen.
      const io = new IntersectionObserver(
        (es) =>
          es.forEach((e) => {
            if (!e.isIntersecting) return
            io.unobserve(e.target)
            const items = Array.from(e.target.querySelectorAll('[data-rise]'))
            animate(items, { opacity: [0, 1], translateY: [28, 0], duration: 800, ease: 'outExpo', delay: stagger(90) })
          }),
        { threshold: 0.25 },
      )
      q('[data-group]').forEach((g) => {
        g.querySelectorAll('[data-rise]').forEach((i) => ((i as HTMLElement).style.opacity = '0'))
        io.observe(g)
      })
      cleanups.push(() => io.disconnect())
    }

    // 3. Scroll: parallax shapes everywhere, and the route that drives the journey on wide screens.
    const journey = el.querySelector<HTMLElement>('.gx-journey')
    const path = el.querySelector<SVGPathElement>('.gx-route-trail')
    const car = el.querySelector<SVGGElement>('.gx-route-car')
    let tl: ReturnType<typeof createTimeline> | null = null
    const live = matchMedia(wide).matches
    if (live && journey && path && car) {
      const total = STEPS.length * SPAN
      const steps = q('.gx-step')
      const shots = q('.gx-shot')
      tl = createTimeline({ autoplay: false, defaults: { ease: 'linear' } })
      tl.add(svg.createDrawable(path), { draw: ['0 0', '0 1'], duration: total }, 0)
      tl.add(car, { ...svg.createMotionPath(path), duration: total }, 0)
      steps.forEach((s, i) => {
        const at = i * SPAN
        const last = i === STEPS.length - 1
        tl!.set(s, { opacity: 0 }, 0)
        tl!.set(shots[i], { opacity: 0 }, 0)
        tl!.add(s, { opacity: [0, 1], translateY: [36, 0], duration: 260, ease: 'outExpo' }, at)
        tl!.add(shots[i], { opacity: [0, 1], translateY: [40, 0], scale: [0.94, 1], filter: ['blur(10px)', 'blur(0px)'], duration: 320, ease: 'outExpo' }, at)
        if (!last) {
          tl!.add(s, { opacity: 0, translateY: -28, duration: 200, ease: 'inQuad' }, at + SPAN - 220)
          tl!.add(shots[i], { opacity: 0, translateY: -30, scale: 0.97, duration: 200, ease: 'inQuad' }, at + SPAN - 220)
        }
      })
      tl.seek(0)
    }

    let raf = 0
    const tick = () => {
      raf = 0
      shell.style.setProperty('--sy', String(window.scrollY))
      if (tl && journey) {
        const r = journey.getBoundingClientRect()
        const p = Math.min(1, Math.max(0, -r.top / (r.height - innerHeight)))
        // stay on the last frame a hair before the end so the final step holds
        tl.seek(p * (STEPS.length * SPAN - 1))
      }
    }
    const onScroll = () => { if (!raf) raf = requestAnimationFrame(tick) }
    addEventListener('scroll', onScroll, { passive: true })
    addEventListener('resize', onScroll)
    tick()
    cleanups.push(() => {
      removeEventListener('scroll', onScroll)
      removeEventListener('resize', onScroll)
      cancelAnimationFrame(raf)
      shell.style.removeProperty('--sy')
    })
    return () => cleanups.forEach((c) => c())
  }, [root])
}

function Home() {
  const ref = useRef<HTMLElement>(null)
  useLandingMotion(ref)
  return (
    <main ref={ref}>
      <section className="gx-hero">
        <svg className="gx-hero-road" viewBox="0 0 1200 700" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
          <path className="gx-ghost" d="M-20 560 C 240 560, 260 200, 560 220 S 860 520, 1220 300" />
          <path className="gx-trail" d="M-20 560 C 240 560, 260 200, 560 220 S 860 520, 1220 300" />
        </svg>
        <div className="gx-copy">
          <h1>
            {WORDS.map((w) => (
              <span key={w} className="gx-ln"><span>{w}</span></span>
            ))}
          </h1>
          <p className="gx-lede gx-hero-fade">
            Add a car by VIN, plan trips with charge and fuel stops, and record every drive over a Bluetooth OBD adapter.
          </p>
          <div className="gx-cta gx-hero-fade">
            <a className="gx-btn gx-btn-p" href="#journey">See how it works</a>
            <Link className="gx-btn" to="/garage/support">Get support</Link>
          </div>
        </div>
        <div className="gx-stage" aria-hidden="true">
          <img className="gx-phone gx-p1" src="/garage/car.png" alt="" />
          <img className="gx-phone gx-p2" src="/garage/live.png" alt="" />
          <span className="gx-chip gx-c1">820 rpm</span>
          <span className="gx-chip gx-c2">Saving on phone</span>
        </div>
      </section>

      <section id="journey" className="gx-journey">
        <div className="gx-pin">
          <div className="gx-steps">
            {STEPS.map((s) => (
              <article key={s.t} className="gx-step">
                <h2>{s.t}</h2>
                <p>{s.d}</p>
                <img className="gx-inline" src={s.img} alt={s.alt} loading="lazy" />
              </article>
            ))}
          </div>
          <div className="gx-device" aria-hidden="true">
            <svg className="gx-route" viewBox="0 0 600 800" aria-hidden="true">
              <path className="gx-ghost" d="M300 -20 C 560 120, 40 220, 300 380 S 560 640, 300 820" />
              <path className="gx-route-trail gx-trail" d="M300 -20 C 560 120, 40 220, 300 380 S 560 640, 300 820" />
              <g className="gx-route-car"><circle r="11" /><circle r="22" className="gx-halo" /></g>
            </svg>
            <div className="gx-frame">
              {STEPS.map((s) => (
                <img key={s.img} className="gx-shot" src={s.img} alt="" />
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="gx-sec gx-adapters" data-group>
        <h2 data-rise>Works with the adapter you already own.</h2>
        <p className="gx-lede" data-rise>
          Any Bluetooth Low Energy OBD-II adapter. iPhone can't use classic Bluetooth (SPP) adapters, so check yours says BLE.
        </p>
        <ul className="gx-pills">
          {ADAPTERS.map((a) => (
            <li key={a} data-rise>{a}</li>
          ))}
          <li data-rise>and other BLE adapters</li>
        </ul>
      </section>

      <section className="gx-sec gx-plan" data-group>
        <h2 data-rise>Plan the trip before you leave.</h2>
        <p className="gx-lede" data-rise>
          Time, the charge or fuel you'll arrive with, what it costs, and the stops along the way. For electric, hybrid and gas cars.
        </p>
      </section>

      <section className="gx-end" data-group>
        <p className="gx-word" aria-label="Garage">
          {'Garage'.split('').map((c, i) => (
            <span key={i} data-rise aria-hidden="true">{c}</span>
          ))}
        </p>
      </section>
    </main>
  )
}

function Doc({ title, children }: { title: string; children: ReactNode }) {
  const ref = useRef<HTMLElement>(null)
  useEffect(() => {
    const root = ref.current
    if (!root) return
    const io = new IntersectionObserver(
      (es) => es.forEach((e) => e.isIntersecting && (e.target.classList.add('gx-in'), io.unobserve(e.target))),
      { threshold: 0.15 },
    )
    root.querySelectorAll('.gx-rv').forEach((el) => io.observe(el))
    return () => io.disconnect()
  }, [])
  return (
    <main ref={ref} className="gx-doc">
      <h1 className="gx-rv">{title}</h1>
      <p className="gx-note gx-rv">Last updated {UPDATED}</p>
      {children}
    </main>
  )
}

function Privacy() {
  return (
    <Doc title="Privacy policy">
      <p className="gx-rv">
        Garage ("the app") records your cars and drives so you can look at them later. This page explains what it
        collects, why, and what you can do about it.
      </p>
      <h2 className="gx-rv">What we collect</h2>
      <ul className="gx-rv">
        <li><b>Account.</b> You sign in with a provider such as Google. We keep the account identifier and the email address it gives us.</li>
        <li><b>Cars.</b> The VIN you enter and the details looked up from it (make, model, year, fuel type), plus any nickname.</li>
        <li><b>Location.</b> Your position while the app is open, to show you on the map and plan routes, and the path of each drive while it is being recorded. Recording can continue with the phone locked, only while a drive is in progress.</li>
        <li><b>Motion.</b> How the car moves (braking, cornering, air pressure) during a drive.</li>
        <li><b>OBD readings.</b> Values from your adapter, such as speed, RPM, coolant temperature, throttle and fuel level.</li>
        <li><b>Places you search for.</b> The text of a search and the origin and destination of a planned route.</li>
      </ul>
      <h2 className="gx-rv">How it is used</h2>
      <p className="gx-rv">
        To show your cars and drives, plan routes, and sync them to your account. We do not sell your data, show ads, or use it
        to track you across other apps and websites.
      </p>
      <h2 className="gx-rv">Who else handles it</h2>
      <ul className="gx-rv">
        <li>Our sign-in provider, to authenticate you.</li>
        <li>Our own servers, which store your cars and drives and answer route and search requests.</li>
        <li>Apple Maps draws the map on your device. If you choose to navigate, the destination is handed to Google Maps or your browser, which have their own policies.</li>
      </ul>
      <h2 className="gx-rv">Your choices</h2>
      <ul className="gx-rv">
        <li>Remove a car from the garage in the app to delete it and its data from our servers.</li>
        <li>Turn off Location, Motion or Bluetooth for the app in iOS Settings at any time. Some features will stop working.</li>
        <li>To delete your account or ask for a copy of your data, contact us from the support page.</li>
      </ul>
      <h2 className="gx-rv">Children</h2>
      <p className="gx-rv">The app is not directed at children under 13.</p>
      <h2 className="gx-rv">Changes</h2>
      <p className="gx-rv">If this policy changes we will update the date above.</p>
      <Contact />
    </Doc>
  )
}

function Support() {
  return (
    <Doc title="Support">
      <h2 className="gx-rv">Common questions</h2>
      <dl className="gx-rv">
        <dt>My adapter won't connect.</dt>
        <dd>Use a Bluetooth Low Energy adapter, plug it into the OBD port and turn the ignition on, then connect from the car's page inside the app. Don't pair it in iOS Settings.</dd>
        <dt>Can I use my classic Bluetooth adapter?</dt>
        <dd>No. iPhone doesn't allow apps to use classic Bluetooth (SPP) adapters. Try the built-in demo drive to see the app first.</dd>
        <dt>The VIN isn't found.</dt>
        <dd>Check all 17 characters, or choose "Enter details by hand" in the Add car screen.</dd>
        <dt>A drive didn't record.</dt>
        <dd>Allow Location "Always" for the app and keep it running during the drive.</dd>
        <dt>How do I delete my data?</dt>
        <dd>Remove a car in the Garage to delete it. For your whole account, contact us below.</dd>
      </dl>
      <Contact />
    </Doc>
  )
}

function Contact() {
  return (
    <aside className="gx-contact gx-rv">
      <h2>Contact</h2>
      {SUPPORT_EMAIL ? (
        <p>Questions or requests: <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a></p>
      ) : (
        <p>Reach us through the Garage page on the App Store.</p>
      )}
    </aside>
  )
}

export default function Garage() {
  return (
    <Shell>
      <Routes>
        <Route index element={<Home />} />
        <Route path="privacy" element={<Privacy />} />
        <Route path="support" element={<Support />} />
        <Route path="*" element={<Home />} />
      </Routes>
    </Shell>
  )
}
