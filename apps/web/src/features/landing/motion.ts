import { useLayoutEffect, type RefObject } from 'react'
import { animate, createScope, createTimeline, onScroll, stagger, utils } from 'animejs'

const OUT = 'outExpo'
const BACK = 'outBack'
const still = () => typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches

/**
 * The landing's motion grammar:
 * - the hero tells the continuity story once: message, reply, memory chip,
 *   thread, second device, chosen check-in — triggered when the scene is seen;
 * - each section then assembles its own scene, inside-out, as it enters;
 * - scroll positions scrub the decorative layers (thread, route, parallax);
 * - calm loops keep the scene alive only where nothing needs reading;
 * - every rule is skipped under reduced motion, and nothing is hidden without JS.
 */
export function useLandingMotion(root: RefObject<HTMLDivElement | null>) {
  useLayoutEffect(() => {
    const el = root.current
    if (!el || still()) return

    let demoIo: IntersectionObserver | null = null
    let railCleanup: (() => void) | null = null
    let focusCleanup: (() => void) | null = null
    let pinCleanup: (() => void) | null = null
    const scope = createScope({ root: el }).add(() => {
      const q = (selector: string) => el.querySelectorAll<HTMLElement | SVGElement>(selector)
      const first = (selector: string) => el.querySelector<HTMLElement>(selector)
      const narrow = matchMedia('(max-width: 760px)').matches

      // Content already on screen at mount must animate now; scroll-triggered
      // reveals only fire when a target crosses into view, so an element that
      // starts inside the viewport would otherwise stay hidden.
      const revealTarget = (target: Element, enter = 'bottom-=14% top') => {
        const rect = target.getBoundingClientRect()
        const inViewOnMount = rect.top < window.innerHeight - 24 && rect.bottom > 0
        return inViewOnMount ? true : onScroll({ target, enter, repeat: false })
      }

      // Numbers that count up with the story; a run token makes a replay
      // cancel the previous run instead of letting two loops race.
      const countUp = (el: HTMLElement, target: number, duration = 900, delay = 0) => {
        const run = String(Number(el.dataset.countRun || 0) + 1)
        el.dataset.countRun = run
        window.setTimeout(() => {
          const start = performance.now()
          const tick = (now: number) => {
            if (el.dataset.countRun !== run) return
            const progress = Math.min(1, (now - start) / duration)
            const eased = progress * progress * (3 - 2 * progress)
            el.textContent = String(Math.round(target * eased))
            if (progress < 1) requestAnimationFrame(tick)
          }
          requestAnimationFrame(tick)
        }, delay)
      }

      // Scenes are demonstrations, not just entrances: each one replays its
      // own explanation whenever it comes back into view. A paused timeline
      // per scene keeps the choreography declarative and restartable.
      const sceneTimelines = new Map<Element, ReturnType<typeof createTimeline>>()
      demoIo = new IntersectionObserver((entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) sceneTimelines.get(entry.target)?.restart()
        }
      }, { threshold: 0.42 })
      const demo = (target: Element | null, make: () => ReturnType<typeof createTimeline>) => {
        if (!target) return
        const timeline = make()
        timeline.pause()
        sceneTimelines.set(target, timeline)
        demoIo?.observe(target)
      }

      /* ------------------------------------------------------------------ */
      /* Hero — staged continuity story                                      */
      /* ------------------------------------------------------------------ */
      const heroScene = first('.lp-hero-scene')
      const continuity = first('.lp-continuity')
      const phone = first('.lp-phone')
      const laptop = first('.lp-laptop')
      const checkin = first('.lp-checkin')
      const threadLine = first('.lp-thread-line')
      const threadDots = q('.lp-thread-dot')
      const token = first('.lp-token')
      const phoneParts = q('.lp-phone .lp-bubble, .lp-phone .lp-chip')
      const laptopParts = q('.lp-laptop-body > *')

      if (phone && laptop && checkin && heroScene && continuity && threadLine && token) {
        // Layout offsets exclude the entrance transforms, so the token path
        // lands on the settled cards rather than their hidden start positions.
        const offsetWithin = (node: HTMLElement, ancestor: HTMLElement) => {
          let x = 0
          let y = 0
          let el: HTMLElement | null = node
          while (el && el !== ancestor) {
            x += el.offsetLeft
            y += el.offsetTop
            el = el.offsetParent as HTMLElement | null
          }
          return { x, y }
        }
        const measureRoute = () => {
          const chipEl = first('.lp-phone .lp-chip')
          const rowEl = first('.lp-laptop .lp-memory-row')
          const checkIcon = first('.lp-checkin-icon')
          if (!chipEl || !rowEl || !checkIcon) return null
          const centerOf = (node: HTMLElement) => {
            const { x, y } = offsetWithin(node, continuity)
            return {
              x: x + node.offsetWidth / 2 - token.offsetWidth / 2,
              y: y + node.offsetHeight / 2 - token.offsetHeight / 2,
            }
          }
          return { start: centerOf(chipEl), read: centerOf(rowEl), end: centerOf(checkIcon) }
        }

        utils.set(phone, { opacity: 0, translateY: 46, scale: 0.96 })
        utils.set(phoneParts, { opacity: 0, translateY: 12, scale: 0.97 })
        utils.set(laptop, { opacity: 0, translateY: 34, translateX: 24 })
        utils.set(laptopParts, { opacity: 0, translateY: 10 })
        utils.set(checkin, { opacity: 0, translateX: 28 })
        utils.set(threadLine, { transformOrigin: 'top center', scaleY: 0 })
        utils.set(threadDots, { opacity: 0, scale: 0 })
        utils.set(token, { opacity: 0, scale: 0.9 })

        // The memory itself travels: phone → remembered at the desk → back as
        // a check-in. The route is measured when it starts, after fonts and
        // layout have settled, and one keyframe tween owns the token so the
        // travel cannot be overwritten by the final fade.
        const playFlow = () => {
          const route = measureRoute()
          if (!route) return
          utils.set(token, { opacity: 0, x: route.start.x, y: route.start.y, scale: 0.9 })
          createTimeline({ defaults: { ease: 'inOutSine' } })
            .add(token, {
              keyframes: [
                { opacity: [0, 1], scale: [0.8, 1], duration: 260 },
                { x: route.read.x, y: route.read.y, duration: 850 },
                { x: route.end.x, y: route.end.y, duration: 780 },
                { opacity: [1, 0], scale: [1, 0.9], duration: 220 },
              ],
            }, 0)
            .add(q('.lp-laptop .lp-memory-row > i'), {
              scale: [1, 1.14, 1], duration: 420, delay: stagger(90),
            }, 1010)
            .add(q('.lp-checkin-icon'), { scale: [1, 1.14, 1], duration: 420 }, 1650)
        }

        createTimeline({
          defaults: { ease: OUT },
          autoplay: revealTarget(heroScene, 'top bottom-=8%'),
        })
          .add(phone, {
            opacity: [0, 1], translateY: [46, 0], scale: [0.96, 1], duration: 760,
          })
          .add(q('.lp-phone .lp-bubble-user'), {
            opacity: [0, 1], translateY: [12, 0], scale: [0.97, 1], duration: 520, ease: BACK,
          }, '-=420')
          .add(q('.lp-phone .lp-bubble-mira'), {
            opacity: [0, 1], translateY: [12, 0], scale: [0.97, 1], duration: 580, ease: BACK,
          }, '-=330')
          .add(q('.lp-phone .lp-chip'), {
            opacity: [0, 1], translateY: [12, 0], duration: 440, ease: BACK,
          }, '-=300')
          .add(threadLine, { scaleY: [0, 1], duration: 840 }, '-=180')
          .add(laptop, {
            opacity: [0, 1], translateY: [34, 0], translateX: [24, 0], duration: 780,
          }, '-=580')
          .add(laptopParts, {
            opacity: [0, 1], translateY: [10, 0], duration: 460, delay: stagger(90),
          }, '-=430')
          .add(threadDots, {
            opacity: [0, 1], scale: [0, 1], duration: 300, delay: stagger(80),
          }, '-=620')
          .add(checkin, {
            opacity: [0, 1], translateX: [28, 0], duration: 700, ease: BACK,
          }, '-=440')
          .call(playFlow, '+=180')
      }

      // Calm signals after assembly: a breathing thread, a bell, live avatars.
      if (threadLine) {
        animate(threadLine, {
          opacity: [0.35, 0.85], duration: 2200, loop: true, alternate: true, ease: 'inOutSine',
        })
      }
      const bell = first('.lp-checkin-icon svg')
      if (bell) {
        animate(bell, {
          rotate: [
            { to: -12, duration: 110 },
            { to: 9, duration: 140 },
            { to: -5, duration: 120 },
            { to: 0, duration: 180 },
          ],
          delay: 1400,
          ease: 'inOutSine',
        })
      }
      animate(q('.lp-memory-icon, .lp-bank > svg'), {
        scale: [1, 1.07], duration: 2200, delay: stagger(260), loop: true, alternate: true, ease: 'inOutSine',
      })
      animate(q('.lp-companion-avatar'), {
        translateY: [0, -3], duration: 2800, delay: stagger(420), loop: true, alternate: true, ease: 'inOutSine',
      })

      // The hero hands off to the story. This is driven by the shared
      // scroll pass rather than a second scroll-linked animation, so it
      // starts from rest and never fights the assembly timeline.
      const heroSection = first('.lp-hero')
      const heroCopy = first('.lp-hero-copy')
      let heroExited = false

      // Each illustration focuses as it crosses the viewport: it enters
      // slightly smaller and dimmer, reaches full presence in the middle,
      // then recedes. Scaling down can never collide with neighbouring copy.
      const focusNodes = Array.from(el.querySelectorAll<HTMLElement>('[data-parallax]'))
      const seamNodes = Array.from(el.querySelectorAll<HTMLElement>('.lp-seam'))
      const applyFocus = () => {
        const vh = window.innerHeight
        for (const node of focusNodes) {
          const stage = node.closest<HTMLElement>('.lp-pin-stage')
          const pin = node.closest<HTMLElement>('.lp-pin')
          if (stage && pin) {
            const stageHeight = stage.offsetHeight
            const stickyTop = parseFloat(getComputedStyle(stage).top) || 96
            const pinnedFor = pin.offsetHeight - stageHeight - stickyTop
            const held = -pin.getBoundingClientRect().top
            if (held > 0 && held < pinnedFor) {
              node.style.opacity = '1'
              node.style.transform = 'none'
              continue
            }
          }
          const rect = node.getBoundingClientRect()
          const center = rect.top + rect.height / 2
          const span = vh / 2 + rect.height / 2
          const offset = Math.min(1, Math.max(-1, (center - vh / 2) / span))
          const raw = 1 - Math.abs(offset)
          const presence = raw * raw * (3 - 2 * raw)
          node.style.opacity = String(0.76 + 0.24 * presence)
          node.style.transform =
            `perspective(1400px) rotateX(${offset * 3}deg) ` +
            `scale(${0.986 + 0.014 * presence})`
        }
        for (const seam of seamNodes) {
          const top = seam.getBoundingClientRect().top
          const progress = Math.min(1, Math.max(0, (vh - top) / vh))
          seam.style.transform = `scaleX(${progress})`
        }
        if (heroSection && heroCopy && heroScene) {
          const heroRect = heroSection.getBoundingClientRect()
          const progress = Math.min(1, Math.max(0, -heroRect.top / Math.max(1, heroRect.height)))
          if (progress > 0) {
            heroExited = true
            heroCopy.style.transform = `translateY(${-44 * progress}px)`
            heroCopy.style.opacity = String(1 - 0.72 * progress)
            heroScene.style.transform =
              `translateY(${(narrow ? -30 : -72) * progress}px) ` +
              `rotate(${-1.6 * progress}deg) scale(${1 - 0.045 * progress})`
            heroScene.style.opacity = String(1 - 0.55 * progress)
          } else if (heroExited) {
            heroExited = false
            heroCopy.style.transform = 'translateY(0px)'
            heroCopy.style.opacity = '1'
            heroScene.style.transform = 'translateY(0px) rotate(0deg) scale(1)'
            heroScene.style.opacity = '1'
          }
        }
      }
      let focusFrame = 0
      const onFocusScroll = () => {
        if (focusFrame) return
        focusFrame = requestAnimationFrame(() => {
          focusFrame = 0
          applyFocus()
        })
      }
      applyFocus()
      window.addEventListener('scroll', onFocusScroll, { passive: true })
      focusCleanup = () => {
        window.removeEventListener('scroll', onFocusScroll)
        if (focusFrame) cancelAnimationFrame(focusFrame)
      }

      // Scenes open like a window as their beat arrives, then settle into
      // parallax; the clip ends outside the box so shadows are never cut.
      el.querySelectorAll<HTMLElement>('[data-parallax] > :is(.lp-scene, .lp-create)').forEach((scene) => {
        utils.set(scene, { clipPath: 'inset(7% 5% 9% 5% round 24px)' })
        animate(scene, {
          clipPath: [
            'inset(7% 5% 9% 5% round 24px)',
            'inset(-20px -20px -20px -20px round 26px)',
          ],
          duration: 1000,
          ease: OUT,
          autoplay: revealTarget(scene, 'bottom-=8% top'),
        })
      })

      // The reading line follows the whole document.
      const progress = first('.lp-reading-progress')
      if (progress) {
        animate(progress, {
          scaleX: [0, 1],
          duration: 1000,
          ease: 'linear',
          autoplay: onScroll({ target: el, enter: 'top top', leave: 'bottom bottom', sync: true }),
        })
      }

      /* ------------------------------------------------------------------ */
      /* Section heads — a single, quiet line-rise                           */
      /* ------------------------------------------------------------------ */
      const revealHead = (section: HTMLElement | null) => {
        if (!section) return
        const targets = section.querySelectorAll('.lp-section-head > *')
        utils.set(targets, { opacity: 0, translateY: 30, clipPath: 'inset(0 0 100% 0)' })
        animate(targets, {
          opacity: [0, 1],
          translateY: [30, 0],
          clipPath: ['inset(0 0 100% 0)', 'inset(0 0 0% 0)'],
          duration: 900,
          delay: stagger(90),
          ease: OUT,
          autoplay: revealTarget(section, 'bottom-=14% top'),
        })
      }

      /* ------------------------------------------------------------------ */
      /* 02 — Memory: left panel, right bank, rows, then the opened source   */
      /* ------------------------------------------------------------------ */
      const why = first('#why')
      revealHead(why)
      const memory = first('#why .lp-memory')
      const memoryPanel = first('#why .lp-memory-panel')
      const bank = first('#why .lp-bank')
      if (memory && memoryPanel && bank) {
        utils.set(memoryPanel, { opacity: 0, translateX: -26 })
        utils.set(bank, { opacity: 0, translateX: 22 })
        animate(memoryPanel, {
          opacity: [0, 1], translateX: [-26, 0], duration: 880, ease: OUT,
          autoplay: revealTarget(memory, 'bottom-=12% top'),
        })
        animate(bank, {
          opacity: [0, 1], translateX: [22, 0], duration: 760, delay: 120, ease: OUT,
          autoplay: revealTarget(memory, 'bottom-=12% top'),
        })

        const rows = memory.querySelectorAll('[data-memory-row]')
        utils.set(rows, { opacity: 0, translateX: -16 })
        animate(rows, {
          opacity: [0, 1], translateX: [-16, 0], duration: 680, delay: stagger(75), ease: OUT,
          autoplay: revealTarget(memory, 'bottom-=16% top'),
        })

        const detail = memory.querySelector('.lp-memory-detail')
        const source = memory.querySelector('.lp-memory-actions .lp-pill')
        const link = memory.querySelector('.lp-memory-link')
        const countEl = memory.querySelector<HTMLElement>('[data-memory-count]')
        if (detail && source) {
          utils.set(detail, { opacity: 0, clipPath: 'inset(0 0 100% 0)' })
          if (link) utils.set(link, { scaleY: 0, transformOrigin: 'top center' })
          animate(detail, {
            opacity: [0, 1],
            clipPath: ['inset(0 0 100% 0)', 'inset(0 0 0% 0)'],
            duration: 680,
            delay: 420,
            ease: OUT,
            autoplay: revealTarget(detail, 'bottom-=10% top'),
          })
          // The demonstration: scan each remembered row, draw the line from
          // the opened memory to its source, and count the bank up.
          const eyes = memory.querySelectorAll('.lp-memory-action')
          demo(memory, () => {
            const timeline = createTimeline({
              autoplay: false,
              defaults: { ease: 'inOutSine' },
              onBegin: () => {
                utils.set(eyes, { opacity: 0.55, scale: 1 })
                if (countEl) countUp(countEl, Number(countEl.getAttribute('data-memory-count') || 24), 900, 900)
              },
            })
              .add(rows, { translateX: [0, 3, 0], duration: 420, delay: stagger(380) }, 400)
              .add(eyes, {
                scale: [1, 1.3, 1], opacity: [0.55, 1, 1], duration: 420, delay: stagger(380),
              }, 400)
              .add(source, { scale: [1, 1.08, 1], duration: 420 }, 1900)
            if (link) {
              timeline.add(link, { scaleY: [0, 1], duration: 520, ease: OUT }, 1150)
            }
            return timeline
          })
        }
      }

      if (why) {
        const labels = why.querySelectorAll('.lp-why-block h3')
        utils.set(labels, { opacity: 0, translateY: 16 })
        animate(labels, {
          opacity: [0, 1],
          translateY: [16, 0],
          duration: 700,
          delay: stagger(100),
          ease: OUT,
          autoplay: revealTarget(why, 'bottom-=12% top'),
        })
      }

      /* ------------------------------------------------------------------ */
      /* 03 — Boundary: permissions flip, approval arrives, egress draws      */
      /* ------------------------------------------------------------------ */
      const boundary = first('#why .lp-boundary')
      const boundaryPanel = first('#why .lp-boundary-panel')
      const approval = first('#why .lp-approval')
      const route = first('#why .lp-route')
      if (boundary && boundaryPanel && approval && route) {
        utils.set(boundaryPanel, { opacity: 0, translateX: -26 })
        utils.set(approval, { opacity: 0, translateY: 22, rotate: 1.4 })
        utils.set(route, { opacity: 0, translateY: 18 })
        animate(boundaryPanel, {
          opacity: [0, 1], translateX: [-26, 0], duration: 860, ease: OUT,
          autoplay: revealTarget(boundary, 'bottom-=12% top'),
        })
        animate(approval, {
          opacity: [0, 1], translateY: [22, 0], rotate: [1.4, 0], duration: 780, delay: 100, ease: BACK,
          autoplay: revealTarget(boundary, 'bottom-=12% top'),
        })
        animate(route, {
          opacity: [0, 1], translateY: [18, 0], duration: 700, delay: 220, ease: OUT,
          autoplay: revealTarget(boundary, 'bottom-=12% top'),
        })

        const fills = boundary.querySelectorAll('.lp-toggle-on .lp-toggle-fill')
        const thumbs = boundary.querySelectorAll('.lp-toggle-on .lp-toggle-thumb')
        utils.set(fills, { scaleX: 0, transformOrigin: 'left center' })
        utils.set(thumbs, { translateX: 0 })
        // One trigger drives both switch parts; a ScrollObserver drives a
        // single animation, so sharing one across separate calls would leave
        // all but the last stuck at their initial state.
        createTimeline({ autoplay: revealTarget(boundary, 'bottom-=18% top') })
          .add(fills, { scaleX: [0, 1], duration: 560, delay: stagger(180), ease: BACK }, 0)
          .add(thumbs, { translateX: [0, 16], duration: 560, delay: stagger(180), ease: BACK }, 0)

        // The demonstration: a request leaves the workspace for the provider.
        // The track and packet replay on entry; on phones the track is hidden.
        const track = first('#why .lp-route-track')
        const packet = first('#why .lp-route-packet')
        if (track && packet && !narrow) {
          const travel = Math.max(60, track.getBoundingClientRect().width)
          utils.set(track, { scaleX: 0, transformOrigin: 'left center' })
          utils.set(packet, { opacity: 0, x: 0 })
          demo(route, () =>
            createTimeline({
              autoplay: false,
              defaults: { ease: 'inOutSine' },
              onBegin: () => {
                utils.set(track, { scaleX: 0 })
                utils.set(packet, { opacity: 0, x: 0 })
              },
            })
              .add(q('#why .lp-approval-actions .lp-btn-solid'), {
                scale: [1, 0.93, 1], duration: 320, ease: 'inOutSine',
              }, 0)
              .add(track, { scaleX: [0, 1], duration: 1400 }, 520)
              .add(packet, { opacity: [0, 1], x: [0, travel], duration: 1400 }, 520)
              .add(packet, { opacity: [1, 0], duration: 200 }, 1890)
              .add(q('#why .lp-route-row .lp-route-chip'), {
                scale: [1, 1.08, 1], duration: 420, delay: stagger(820),
              }, 620),
          )
        }
      }

      /* ------------------------------------------------------------------ */
      /* 04 — Artifact: conversation on the left, plan assembles on the right */
      /* ------------------------------------------------------------------ */
      const what = first('#what')
      revealHead(what)
      const chatCard = first('#what .lp-chat-card')
      const planCard = first('#what .lp-plan-card')
      if (what && chatCard && planCard) {
        utils.set(chatCard, { opacity: 0, translateX: -28 })
        utils.set(planCard, { opacity: 0, translateX: 28, rotate: 1.2 })
        utils.set(q('#what .lp-chat-card .lp-bubble'), { opacity: 0, translateY: 10 })
        animate(chatCard, {
          opacity: [0, 1], translateX: [-28, 0], duration: 860, ease: OUT,
          autoplay: revealTarget(what, 'bottom-=14% top'),
        })
        animate(q('#what .lp-chat-card .lp-bubble'), {
          opacity: [0, 1], translateY: [10, 0], duration: 520, delay: stagger(220), ease: BACK,
          autoplay: revealTarget(what, 'bottom-=14% top'),
        })
        animate(planCard, {
          opacity: [0, 1], translateX: [28, 0], rotate: [1.2, 0], duration: 880, delay: 120, ease: OUT,
          autoplay: revealTarget(what, 'bottom-=14% top'),
        })

        const items = what.querySelectorAll('[data-plan-item]')
        utils.set(items, { opacity: 0, translateY: 14 })
        animate(items, {
          opacity: [0, 1], translateY: [14, 0], duration: 620, delay: stagger(100), ease: OUT,
          autoplay: revealTarget(what, 'bottom-=18% top'),
        })

        const checkIcons = what.querySelectorAll('.lp-plan-check svg')
        const draft = first('#what .lp-plan-head .lp-pill')
        const review = first('#what .lp-plan-actions .lp-btn-solid')
        const artifactScene = first('#what .lp-artifact')
        const spark = first('#what .lp-artifact-spark')
        if (draft && review) {
          utils.set(checkIcons, { opacity: 0, scale: 0.3 })
          utils.set(draft, { scale: 0.7, opacity: 0, rotate: -6 })

          let start = { x: 0, y: 0 }
          let end = { x: 0, y: 0 }
          if (artifactScene && spark) {
            const offsetWithin = (node: HTMLElement, ancestor: HTMLElement) => {
              let x = 0
              let y = 0
              let el: HTMLElement | null = node
              while (el && el !== ancestor) {
                x += el.offsetLeft
                y += el.offsetTop
                el = el.offsetParent as HTMLElement | null
              }
              return { x, y }
            }
            const chatAt = offsetWithin(chatCard, artifactScene)
            const planAt = offsetWithin(planCard, artifactScene)
            start = {
              x: chatAt.x + chatCard.offsetWidth - spark.offsetWidth - 12,
              y: chatAt.y + chatCard.offsetHeight - spark.offsetHeight - 12,
            }
            end = { x: planAt.x + 20, y: planAt.y + 20 }
            utils.set(spark, { x: start.x, y: start.y, opacity: 0, scale: 0.85 })
          }

          // The demonstration: the conversation's draft leaves the chat,
          // lands on the plan, and only then are the steps checked and the
          // plan offered for review. On desktop this whole sequence is
          // scrubbed by the pinned chapter instead of played on entry.
          const buildArtifact = () => {
            const timeline = createTimeline({
              autoplay: false,
              defaults: { ease: BACK },
              onBegin: () => {
                utils.set(checkIcons, { opacity: 0, scale: 0.3 })
                utils.set(draft, { opacity: 0, scale: 0.7, rotate: -6 })
                if (spark) utils.set(spark, { opacity: 0, scale: 0.85, x: start.x, y: start.y })
              },
            })
            if (spark) {
              timeline
                .add(spark, { opacity: [0, 1], scale: [0.85, 1], duration: 260, ease: OUT }, 250)
                .add(spark, {
                  x: [start.x, end.x], y: [start.y, end.y], duration: 820, ease: 'inOutSine',
                }, 420)
                .add(spark, { opacity: [1, 0], scale: [1, 0.9], duration: 200 }, 1280)
            }
            timeline
              .add(checkIcons, {
                opacity: [0, 1], scale: [0.3, 1], duration: 420, delay: stagger(260),
              }, 1400)
              .add(draft, {
                scale: [0.7, 1.05, 1], opacity: [0, 1], rotate: [-6, 0], duration: 560,
              }, 2200)
              .add(review, {
                scale: [1, 1.05, 1], duration: 480, ease: 'inOutSine',
              }, 2800)
            return timeline
          }

          const pin = first('#what .lp-pin')
          if (pin && matchMedia('(min-width: 1100px)').matches) {
            const timeline = buildArtifact()
            timeline.pause()
            let frame = 0
            const update = () => {
              frame = 0
              const rect = pin.getBoundingClientRect()
              const stage = pin.querySelector<HTMLElement>('.lp-pin-stage')
              const stageHeight = stage?.offsetHeight ?? 400
              const stickyTop = stage ? (parseFloat(getComputedStyle(stage).top) || 96) : 96
              const span = Math.max(1, pin.offsetHeight - stageHeight - stickyTop)
              const progress = Math.min(1, Math.max(0, -rect.top / span))
              timeline.seek(progress * timeline.duration)
            }
            const onPinScroll = () => {
              if (!frame) frame = requestAnimationFrame(update)
            }
            window.addEventListener('scroll', onPinScroll, { passive: true })
            update()
            pinCleanup = () => {
              window.removeEventListener('scroll', onPinScroll)
              if (frame) cancelAnimationFrame(frame)
            }
          } else {
            demo(artifactScene ?? what, buildArtifact)
          }
        }
      }

      /* ------------------------------------------------------------------ */
      /* 05 — Companions: the fan opens from the centre                      */
      /* ------------------------------------------------------------------ */
      const companions = first('#companions')
      revealHead(companions)
      if (companions) {
        const tabs = first('#companions .lp-companion-tabs')
        const atlas = first('#companions .lp-companion-atlas')
        const mira = first('#companions .lp-companion-mira')
        const june = first('#companions .lp-companion-june')
        const add = first('#companions .lp-add-companion')

        if (tabs && atlas && mira && june && add) {
          utils.set(tabs, { opacity: 0, translateY: -10 })
          utils.set(atlas, { opacity: 0, translateX: -36 })
          utils.set(june, { opacity: 0, translateX: 36 })
          utils.set(mira, { opacity: 0, translateY: 24, scale: 0.94 })
          utils.set(add, { opacity: 0, translateY: 12 })

          const at = revealTarget(companions, 'bottom-=14% top')
          createTimeline({ defaults: { ease: BACK }, autoplay: at })
            .add(tabs, { opacity: [0, 1], translateY: [-10, 0], duration: 560, ease: OUT }, 0)
            .add(mira, { opacity: [0, 1], translateY: [24, 0], scale: [0.94, 1], duration: 940 }, 60)
            .add(atlas, { opacity: [0, 1], translateX: [-36, 0], duration: 900 }, 120)
            .add(june, { opacity: [0, 1], translateX: [36, 0], duration: 900 }, 200)
            .add(add, { opacity: [0, 1], translateY: [12, 0], duration: 620, ease: OUT }, 620)

          // The demonstration: attention moves companion by companion, each
          // lifting its own memory bank and counting its own entries — one
          // life, separate memories.
          demo(companions, () => {
            const timeline = createTimeline({
              autoplay: false,
              defaults: { ease: 'inOutSine' },
              onBegin: () => {
                companions.querySelectorAll<HTMLElement>('[data-count]').forEach((el, index) => {
                  countUp(el, Number(el.getAttribute('data-count') || 0), 700, 1100 + index * 1000)
                })
              },
            })
              .add(q('#companions [data-companion-card]'), {
                translateY: [0, -7, 0], duration: 900, delay: stagger(1000),
              }, 900)
              .add(q('#companions .lp-companion-memory'), {
                scale: [1, 1.06, 1], duration: 900, delay: stagger(1000),
              }, 900)
            return timeline
          })
        }
      }

      /* ------------------------------------------------------------------ */
      /* 06 — How: the creation preview assembles, then reacts in place       */
      /* ------------------------------------------------------------------ */
      const how = first('#how')
      revealHead(how)
      const controls = first('#how .lp-create-controls')
      const preview = first('#how .lp-create-preview')
      if (how && controls && preview) {
        utils.set(controls, { opacity: 0, translateX: -22 })
        utils.set(preview, { opacity: 0, translateX: 24, rotate: 1.6 })
        animate(controls, {
          opacity: [0, 1], translateX: [-22, 0], duration: 760, ease: OUT,
          autoplay: revealTarget(how, 'bottom-=14% top'),
        })
        animate(preview, {
          opacity: [0, 1], translateX: [24, 0], rotate: [1.6, 0], duration: 860, delay: 120, ease: BACK,
          autoplay: revealTarget(how, 'bottom-=14% top'),
        })

        const steps = how.querySelectorAll('.lp-how-step')
        utils.set(steps, { opacity: 0, translateY: 18 })
        animate(steps, {
          opacity: [0, 1], translateY: [18, 0], duration: 620, delay: stagger(110), ease: OUT,
          autoplay: revealTarget(how, 'bottom-=18% top'),
        })
      }

      /* ------------------------------------------------------------------ */
      /* Close — the mark settles, the last line lands                       */
      /* ------------------------------------------------------------------ */
      const closing = first('.lp-closing')
      if (closing) {
        const items = closing.querySelectorAll('[data-closing-reveal]')
        utils.set(items, { opacity: 0, translateY: 24 })
        animate(items, {
          opacity: [0, 1],
          translateY: [24, 0],
          duration: 850,
          delay: stagger(100),
          ease: OUT,
          autoplay: revealTarget(closing, 'bottom-=10% top'),
        })
        const mark = closing.querySelector('.lp-companion-mark svg')
        if (mark) {
          animate(mark, {
            rotate: [0, 10, 0], scale: [1, 1.06], duration: 3600, loop: true, ease: 'inOutSine',
          })
        }
      }

      /* ------------------------------------------------------------------ */
      /* Footer                                                             */
      /* ------------------------------------------------------------------ */
      const footer = el.querySelector<HTMLElement>('.lp-footer')
      if (footer) {
        const items = footer.querySelectorAll(':scope > *')
        utils.set(items, { opacity: 0, translateY: 18 })
        animate(items, {
          opacity: [0, 1],
          translateY: [18, 0],
          duration: 760,
          delay: stagger(80),
          ease: OUT,
          autoplay: revealTarget(footer, 'bottom-=4% top'),
        })
      }

      /* ------------------------------------------------------------------ */
      /* Chapter rail — the thread carries the whole story                   */
      /* ------------------------------------------------------------------ */
      const rail = first('.lp-rail')
      const main = el.querySelector<HTMLElement>('main')
      if (rail && main) {
        const nodes = new Map<string, HTMLElement>()
        rail.querySelectorAll<HTMLElement>('[data-rail-node]').forEach((node) => {
          nodes.set(node.dataset.railNode ?? '', node)
        })
        const sections = Array.from(el.querySelectorAll<HTMLElement>('main section'))

        const position = () => {
          const lpTop = el.getBoundingClientRect().top + window.scrollY
          const mainTop = main.getBoundingClientRect().top + window.scrollY
          rail.style.top = `${mainTop - lpTop}px`
          rail.style.height = `${main.offsetHeight}px`
          sections.forEach((section) => {
            const node = nodes.get(section.id)
            if (!node) return
            const y = section.getBoundingClientRect().top + window.scrollY - mainTop
            node.style.top = `${y}px`
          })
          rail.classList.add('is-ready')
        }
        position()
        window.addEventListener('resize', position)
        document.fonts?.ready.then(() => position())

        const activeIo = new IntersectionObserver((entries) => {
          for (const entry of entries) {
            if (!entry.isIntersecting) continue
            nodes.forEach((node) => node.classList.remove('is-active'))
            nodes.get((entry.target as HTMLElement).id)?.classList.add('is-active')
          }
        }, { rootMargin: '-42% 0px -50% 0px', threshold: 0 })
        sections.forEach((section) => activeIo.observe(section))

        const fill = rail.querySelector('.lp-rail-fill')
        if (fill) {
          animate(fill, {
            scaleY: [0, 1],
            ease: 'linear',
            autoplay: onScroll({ target: main, enter: 'top top', leave: 'bottom bottom', sync: true }),
          })
        }

        // The pulse is the reading head: one dot carried down the thread.
        const pulse = rail.querySelector<HTMLElement>('.lp-rail-pulse')
        let pulseFrame = 0
        const updatePulse = () => {
          pulseFrame = 0
          if (!pulse) return
          const max = Math.max(0, rail.clientHeight - 9)
          const rect = main.getBoundingClientRect()
          const span = Math.max(1, rect.height - window.innerHeight)
          const progress = Math.min(1, Math.max(0, -rect.top / span))
          pulse.style.transform = `translateY(${progress * max}px)`
        }
        const onRailScroll = () => {
          if (!pulseFrame) pulseFrame = requestAnimationFrame(updatePulse)
        }
        window.addEventListener('scroll', onRailScroll, { passive: true })
        updatePulse()

        railCleanup = () => {
          window.removeEventListener('resize', position)
          window.removeEventListener('scroll', onRailScroll)
          if (pulseFrame) cancelAnimationFrame(pulseFrame)
          activeIo.disconnect()
        }
      }
    })

    return () => {
      demoIo?.disconnect()
      railCleanup?.()
      focusCleanup?.()
      pinCleanup?.()
      scope.revert()
    }
  }, [root])
}

/**
 * Reference-page motion: a mount reveal for the head and status legend, a
 * staggered matrix on mount, scroll-linked section entries with their inner
 * cards, and a route that draws as the reader moves through the argument.
 */
export function useInfoMotion(root: RefObject<HTMLDivElement | null>) {
  useLayoutEffect(() => {
    const el = root.current
    if (!el || still()) return

    let demoIo: IntersectionObserver | null = null
    const scope = createScope({ root: el }).add(() => {
      const q = (selector: string) => el.querySelectorAll<HTMLElement>(selector)
      const first = (selector: string) => el.querySelector<HTMLElement>(selector)

      // Same rule as the landing: content already in view animates on mount.
      const revealTarget = (target: Element, enter = 'bottom-=14% top') => {
        const rect = target.getBoundingClientRect()
        const inViewOnMount = rect.top < window.innerHeight - 24 && rect.bottom > 0
        return inViewOnMount ? true : onScroll({ target, enter, repeat: false })
      }

      const sceneTimelines = new Map<Element, ReturnType<typeof createTimeline>>()
      demoIo = new IntersectionObserver((entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) sceneTimelines.get(entry.target)?.restart()
        }
      }, { threshold: 0.42 })
      const demo = (target: Element | null, make: () => ReturnType<typeof createTimeline>) => {
        if (!target) return
        const timeline = make()
        timeline.pause()
        sceneTimelines.set(target, timeline)
        demoIo?.observe(target)
      }

      const head = q('.lp-info-head > *')
      const legend = q('.lp-status-legend > *')
      utils.set(head, { opacity: 0, translateY: 18 })
      utils.set(legend, { opacity: 0, translateY: 12 })

      createTimeline({ defaults: { ease: OUT } })
        .add(head, { opacity: [0, 1], translateY: [18, 0], duration: 820, delay: stagger(80) })
        .add(legend, { opacity: [0, 1], translateY: [12, 0], duration: 600, delay: stagger(55) }, '-=540')

      const rows = q('[data-info-row]')
      if (rows.length) {
        // Each capability arrives as it is reached; its status pill settles
        // a beat later, so availability reads as the answer to the row.
        rows.forEach((row) => {
          const status = row.querySelector('.lp-info-cap-status')
          if (!status) return
          utils.set(row, { opacity: 0, translateY: 14 })
          utils.set(status, { scale: 0.85 })
          createTimeline({
            defaults: { ease: OUT },
            autoplay: revealTarget(row, 'bottom-=6% top'),
          })
            .add(row, { opacity: [0, 1], translateY: [14, 0], duration: 600 })
            .add(status, { scale: [0.85, 1], duration: 460, ease: BACK }, 140)
        })
      }

      // Each section arrives as a block, then its contents follow inside it.
      q('[data-info-reveal]').forEach((node) => {
        const copy = node.querySelectorAll(':scope > h2, :scope > p')
        const inner = node.querySelectorAll(
          '.lp-info-card, .lp-info-list li, .lp-route-chip, .lp-info-route-arrow, .lp-info-callout',
        )
        utils.set(node, { opacity: 0, translateY: 20 })
        utils.set(copy, { translateY: 22, clipPath: 'inset(0 0 100% 0)' })
        animate(node, {
          opacity: [0, 1],
          translateY: [20, 0],
          duration: 720,
          ease: OUT,
          autoplay: revealTarget(node, 'bottom-=12% top'),
        })
        if (copy.length) {
          animate(copy, {
            translateY: [22, 0],
            clipPath: ['inset(0 0 100% 0)', 'inset(0 0 0% 0)'],
            duration: 820,
            delay: stagger(90),
            ease: OUT,
            autoplay: revealTarget(node, 'bottom-=12% top'),
          })
        }
        if (inner.length) {
          utils.set(inner, { opacity: 0, translateY: 12 })
          animate(inner, {
            opacity: [0, 1],
            translateY: [12, 0],
            duration: 600,
            delay: stagger(70),
            ease: OUT,
            autoplay: revealTarget(node, 'bottom-=14% top'),
          })
        }
      })

      const route = first('.lp-info-route')
      const routeLine = first('.lp-info-route-line')
      const routePacket = first('.lp-info-route-packet')
      if (route && routeLine && routePacket) {
        const travel = Math.max(80, routeLine.getBoundingClientRect().width)
        utils.set(routeLine, { scaleX: 0, transformOrigin: 'left center' })
        utils.set(routePacket, { opacity: 0, x: 0 })
        // The demonstration: only the request context crosses the boundary.
        demo(route, () =>
          createTimeline({
            autoplay: false,
            defaults: { ease: 'inOutSine' },
            onBegin: () => {
              utils.set(routeLine, { scaleX: 0 })
              utils.set(routePacket, { opacity: 0, x: 0 })
            },
          })
            .add(routeLine, { scaleX: [0, 1], duration: 1400 }, 250)
            .add(routePacket, { opacity: [0, 1], x: [0, travel], duration: 1400 }, 250)
            .add(routePacket, { opacity: [1, 0], duration: 200 }, 1620)
            .add(q('.lp-info-route .lp-route-chip'), {
              scale: [1, 1.06, 1], duration: 420, delay: stagger(600),
            }, 400),
        )
      }

      const progress = first('.lp-reading-progress')
      if (progress) {
        animate(progress, {
          scaleX: [0, 1],
          duration: 1000,
          ease: 'linear',
          autoplay: onScroll({ target: el, enter: 'top top', leave: 'bottom bottom', sync: true }),
        })
      }
    })

    return () => {
      demoIo?.disconnect()
      scope.revert()
    }
  }, [root])
}
