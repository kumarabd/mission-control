---
name: "Mission Control"
description: "Sage signal, warm paper and ink-dark surfaces for personal companions."
colors:
  dark-primary: "#a9c985"
  dark-primary-hover: "#c2dda5"
  dark-on-primary: "#18211b"
  dark-background: "#101211"
  dark-surface: "#191d1b"
  dark-muted: "#222824"
  dark-tint: "#263122"
  dark-tint-soft: "#1c211e"
  dark-border: "#313a35"
  dark-border-strong: "#455047"
  dark-foreground: "#e8eee9"
  dark-muted-fg: "#a8b2aa"
  dark-accent: "#74b9c8"
  dark-success: "#8fce99"
  dark-warning: "#f2c879"
  dark-danger: "#e6a18c"
  light-primary: "#4e6a37"
  light-primary-hover: "#3d572a"
  light-on-primary: "#ffffff"
  light-background: "#f7f8f3"
  light-surface: "#ffffff"
  light-muted: "#e5e8df"
  light-tint: "#e7eddc"
  light-tint-soft: "#eff1ea"
  light-border: "#ced1c5"
  light-border-strong: "#aab4a5"
  light-foreground: "#18211b"
  light-muted-fg: "#566159"
  light-accent: "#2e6f7e"
  light-success: "#35734a"
  light-warning: "#8a6619"
  light-danger: "#9a4c3e"
typography:
  display:
    fontFamily: "\"Hanken Grotesk Variable\", ui-sans-serif, system-ui, sans-serif"
    fontSize: "3.5rem"
    fontWeight: 600
    lineHeight: 1.02
    letterSpacing: "-0.022em"
  headline:
    fontFamily: "\"Hanken Grotesk Variable\", ui-sans-serif, system-ui, sans-serif"
    fontSize: "2rem"
    fontWeight: 600
    lineHeight: 1.12
    letterSpacing: "-0.018em"
  title:
    fontFamily: "\"Hanken Grotesk Variable\", ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "-0.006em"
  body:
    fontFamily: "\"Hanken Grotesk Variable\", ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "\"Hanken Grotesk Variable\", ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.6875rem"
    fontWeight: 500
    lineHeight: 1.45
    letterSpacing: "0.005em"
  mono:
    fontFamily: "\"IBM Plex Mono\", ui-monospace, \"SF Mono\", Menlo, monospace"
    fontSize: "0.6875rem"
    fontWeight: 400
  landing-display:
    fontFamily: "\"Hanken Grotesk Variable\", ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(3rem, 5.7vw, 5.1rem)"
    fontWeight: 450
    lineHeight: 1.04
    letterSpacing: "-0.04em"
  landing-headline:
    fontFamily: "\"Hanken Grotesk Variable\", ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(2.6rem, 4.7vw, 4.2rem)"
    fontWeight: 450
    lineHeight: 1.04
    letterSpacing: "-0.04em"
  landing-body:
    fontFamily: "\"Hanken Grotesk Variable\", ui-sans-serif, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.65
rounded:
  xs: "3px"
  sm: "5px"
  md: "8px"
  lg: "12px"
  full: "9999px"
  landing-cta: "9px"
  landing-scene-card: "13px"
  landing-scene-frame: "28px"
spacing:
  1: "4px"
  1-5: "6px"
  2: "8px"
  3: "12px"
  4: "16px"
  6: "24px"
  8: "32px"
components:
  button-primary:
    backgroundColor: "var(--color-flat-primary)"
    textColor: "var(--color-flat-on-primary)"
    rounded: "{rounded.sm}"
    height: "36px"
    padding: "0 14px"
  button-primary-hover:
    backgroundColor: "var(--color-flat-primary-hover)"
  button-secondary:
    backgroundColor: "var(--color-flat-muted)"
    textColor: "var(--color-flat-foreground)"
    rounded: "{rounded.sm}"
    height: "36px"
    padding: "0 14px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "var(--color-flat-muted-fg)"
    rounded: "{rounded.sm}"
    height: "36px"
    padding: "0 14px"
  button-outline:
    backgroundColor: "transparent"
    textColor: "var(--color-flat-foreground)"
    rounded: "{rounded.sm}"
    height: "36px"
    padding: "0 14px"
  input:
    backgroundColor: "var(--color-flat-surface)"
    textColor: "var(--color-flat-foreground)"
    rounded: "{rounded.sm}"
    height: "36px"
    padding: "0 12px"
  badge-accent:
    backgroundColor: "var(--color-flat-tint)"
    textColor: "var(--color-flat-primary)"
    rounded: "{rounded.xs}"
    padding: "2px 8px"
    typography: "{typography.label}"
  landing-button:
    backgroundColor: "var(--color-flat-primary)"
    textColor: "var(--color-flat-on-primary)"
    rounded: "{rounded.landing-cta}"
    padding: "13px 24px"
  landing-scene:
    backgroundColor: "var(--color-flat-tint-soft)"
    textColor: "var(--color-flat-foreground)"
    rounded: "{rounded.landing-scene-frame}"
    width: "100%"
  card:
    backgroundColor: "var(--color-flat-surface)"
    textColor: "var(--color-flat-foreground)"
    padding: "16px"
  companion-mark:
    backgroundColor: "var(--color-flat-tint)"
    textColor: "var(--color-flat-primary)"
    width: "64px"
    height: "64px"
---

# Design System: Mission Control

## Overview

**Creative North Star: "A home for personal companions"**

Mission Control pairs warm paper and ink-dark surfaces with a sage signal color. Hanken Grotesk carries both expressive public-page typography and compact workspace controls; IBM Plex Mono marks occasional technical metadata. The personality is approachable, calm and readable.

The public landing extends that world through open editorial bands and layered functional UI scenes: a companion takes shape, carries context and produces useful examples. Fine connecting lines and physical card assembly explain continuity and choice. The authenticated application is denser, using shared controls and bordered containers. The landing’s story order and compositions belong to its surface brief rather than becoming application-wide rules.

**Key Characteristics:**
- One semantic palette with light and dark modes.
- Sage for the active path and primary action; separate telemetry and status colors.
- Shared sans typography with restrained technical mono.
- Fine borders and tonal surfaces; generous public-page spacing.
- Layered public scenes with looping explanatory motion and readable static alternatives.

## Colors

The palette keeps green-tinted neutrals quiet and gives sage a clear signaling role. Frontmatter records literal values by mode; application code consumes the live `--color-flat-*` aliases from `src/index.css`, backed by `src/themes.css`. Use those aliases in new UI rather than copying a mode-specific value.

### Primary

- **Sage signal:** primary action, active path and public-page emphasis; pair with on-primary for filled controls. Primary-hover supplies the interactive shade.

### Secondary

- **Telemetry teal:** the existing accent role for system activity, separate from the sage primary.
- **Health green, attention amber and failure clay:** success, warning and danger are semantic states. Their muted fill companions remain in the source theme.

### Neutral

- **Paper / ink canvas:** page background, with surface and muted roles for controls and containers.
- **Soft sage:** tint for active items and tint-soft for quieter sectional contrast.
- **Reading ink / light ink:** foreground for essential text; muted foreground for secondary text.
- **Fine rule / strong rule:** border for structure and border-strong for stronger or interactive boundaries.
- **Subtle foreground:** intentionally below normal text contrast; not a body-copy role and omitted from the normative reusable text palette here.


**The Semantic Pair Rule.** Use foreground/background and primary/on-primary pairs from the same active theme. Preserve semantic roles when switching modes.

**The Signal Rule.** Use sage for the active path and primary action, telemetry teal for system activity, and status colors for their stated meaning.

## Typography

**Display and Body Font:** Hanken Grotesk Variable, with the existing UI sans stack as fallback.
**Label/Mono Font:** IBM Plex Mono, with the existing monospace stack as fallback.

The same sans family provides a compact, practical workspace and a lighter editorial public page. Both font families are installed and imported in `src/main.tsx`.

### Hierarchy

- **Display:** app’s 5xl token for the largest workspace headings; use only where needed.
- **Headline:** app’s 3xl token for major titles; the full source ramp also includes intermediate sizes.
- **Title:** app’s lg token for compact section and card headings.
- **Body:** root body uses the md token; base text utilities use the smaller base token (0.875rem). The public page instead uses landing-body.
- **Label:** 2xs is for compact badges and metadata, with larger labels where needed. Mono is reserved for existing technical contexts.
- **Landing display / headline:** public-page-only responsive roles with lighter weight and close tracking. Display adjusts at 980px and 760px; at 380px and below it is 2.65rem. Headline adjusts at 760px. Hero copy is 18px on desktop and 17px at compact widths; scene type scales to its container.

**The Surface Scale Rule.** Use the compact shared type scale in workspace UI. The larger, lighter public-page headings belong to the landing surface.

## Layout

Workspace layouts use compact spacing steps and shared UI components. The sidebar is full or collapsed (240px / 56px); these shell dimensions are not a landing-page grid.

On the public landing, content stays in normal document flow with one page scroll. Main sections cap at 1320px; header and footer cap at 1440px. Gutters use `clamp(20px, 4.5vw, 64px)` and section padding scales with `clamp(64px, 8vw, 112px)`. Desktop pairs a headline and signup with a large functional scene. The hero’s scene reserves a 560:500 stage, becoming square at 480px and below; its internal type responds to container width.

At 1100px, the day selector moves into four columns above its theatre, and the creation controls stack below their preview. At 980px, the header navigation takes its own row; the hero becomes one column with a two-column copy block, the main story layouts stack, and creation returns to paired controls and preview. At 760px, hero content reorders to headline → visual scene → explanation → action, section introductions and day dialogue/artifact stack, selectors form two columns, and section padding becomes 64px. At 480px, creation stacks with its preview first and scene details compact. At 380px, gutters become 18px and context notes stack. The day’s inactive moments reserve one grid area to avoid playback-driven page jumps; scenes do not create nested scrollers. Root horizontal clipping contains the animated canvas; it is a containment guard, not a separate scroll surface.

Fine rules and soft tonal bands separate the public scenes. Hero and story copy cap at 42ch, with day-scene prose and output kept in distinct readable columns on desktop. The narrative order and first-viewport intent remain in [the landing surface brief](docs/design/landing-surface.md).

## Elevation & Depth

The public landing combines open tonal bands with layered functional scenes. Intent and output cards use elevation 1; the companion identity and creation preview use elevation 2. Fine sage connections describe relationships, and a dashed privacy boundary describes a choice of context rather than an encryption guarantee. Workspace components retain their existing elevation behavior: shared cards are flat by default and accept elevation 1, while floating panels and dialogs use stronger shadows. Dark mode’s first elevation is a hairline; stronger tiers and light mode use soft cast shadows. The sidecar records all three existing shadow tiers for both modes and the focus ring.

Shared state transitions retain their existing easing and duration tokens. Public storytelling uses Motion for React (`motion/react`). The landing has no Pause/Play or Replay story control and no explicit hover, focus, offscreen or background suspension. Hero topics cycle every 6.2 seconds; day moments cycle every 6.5 seconds, including last → first. Manual day selection starts a fresh full dwell before cycling continues; keyboard selection is immediate. Identity and shared-preference drift, companion-mark breathing, hero/context linework and the 7-second creation-preview movement repeat continuously. OS reduced motion removes spatial effects and CSS animation while illustrative content still cycles.

The scroll journey uses stationary measurement frames and separate moving layers. Across viewport passage (`start end` → `end start`), the hero departs to −100px / −4°, while the day opens from 72px / 8° / 94%, holds its settled form and departs to −64px / −5° / 97% with 1400px perspective. Paired copy and scenes use opposing horizontal tracks, responsive clamps and different vertical speeds. A kinetic bridge moves its two lines through opposing ±8% tracks, carries the companion from 32px / −20° to −32px / 20°, and draws the connecting thread. Headings settle from −24px / 1° to rest. Closing identities fan to ±18px / ±20° on desktop, with a center lift from 18px to −24px; at 760px and below, fixed fan units reduce the horizontal and angular ranges to 40% and 60%. Focus within removes outer frame and slot transforms without stopping internal playback or loops. Reduced motion settles spatial layers and fully draws connections. These are landing-specific mappings; the sidecar records their exact progress points.

## Shapes

The shared radius scale runs from small squared corners through gentle rounding to pills. Buttons and text inputs use small corners; badges use the smallest step. Existing shared cards use Tailwind’s 2xl radius (16px), separate from the locally declared xs–lg scale. The public CTA has its own 9px corners. Public scene cards use gentle rounding (typically 12–13px), with larger enclosing stages (20–28px); these scene roles do not replace shared card shapes. The companion mark has an asymmetric speech-like corner (20px 20px 20px 6px), reducing to 13px 13px 13px 4px for its small form, with container-specific adjustments in the scenes. Fine structural borders are 1px; the illustrative privacy boundary is a 1.5px dashed sage line.

## Components

### Buttons

Compact workspace actions use the shared Button. Primary is sage with on-primary text; secondary uses muted fill and a fine border; ghost uses muted text and gains a muted fill; outline uses the stronger border. Sizes are sm, md and lg (32px, 36px, 40px tall) with matching horizontal padding. Focus uses the primary ring and background offset; disabled and loading controls suppress interaction and reduce opacity. Existing legacy variant aliases are compatibility paths, not new API choices.

The public landing CTA is deliberately larger: a 52px minimum height, 9px corners, 13px 24px padding and 24px icon gap. Its small form has a 44px minimum height. Fine-pointer hover uses primary-hover and rises 2px; press scales to .97, and reduced motion removes transform feedback. Links use the existing auth-aware action destination: account setup comes before first use, and an existing account can return to its workspace.

The shared danger variant exists, but its white text is not adopted as a normative pairing here: it requires contrast review in dark mode.

### Chips

Badge exposes neutral, accent, success, warning and danger tones, with soft, solid and outline fills. The accent soft form uses tint and primary. Compact badges have smallest-step corners and optional dot; Tag supports removal and explicit category colors. Use text as well as color to carry status. The source’s solid status variants require their own contrast checks rather than automatic reuse.

### Cards / Containers

Shared Card uses a surface fill, fine border, existing 2xl corners and 16px padding by default (12px or none are supported). Interactive containers change border and surface color; elevation 1 is optional. Public bands retain open spacing and fine rules, while the illustrative scenes assemble distinct intent, identity, context and output surfaces with the existing shadow tiers.

### Inputs / Fields

Shared Field supplies an associated label, hint or error. Input and Textarea use surface fill, small corners and a fine border. Input sizes are 32px or 36px; default horizontal padding is 12px, increased around icons. Focus changes the border to primary and adds a translucent primary ring; invalid fields use danger for both. Disabled fields reduce opacity and show the unavailable cursor. Placeholder color uses subtle foreground and must not replace a label.

### Navigation

Workspace sidebar rows use small corners, compact spacing, muted text and a soft tint for the active row; the active icon is sage. Routed tabs use a sage underline and foreground text for the current page. The public header uses ordinary section links with a 44px minimum target, separating into a full-width row on small screens. These remain distinct navigation patterns.

### Companion scenes

A tinted asymmetric mark and the stable Mira identity connect the public story. The hero visibly links an intention, a companion and useful output with fine sage wires. The day theatre pairs conversation with an artifact, exposes each choice’s pressed state, and highlights the selection with a soft tonal fill and border. Inactive moments share a grid area and reserve stable height; they are hidden from the accessibility tree. Controls remain separate from the noninteractive illustrative content.

Context notes converge into a useful second perspective, with the proactive example explicitly marked in development. A privacy switch exposes its checked state and changes only the local illustration; the provider-processing note remains outside the account boundary. Creation uses a labeled name input and pressed-state personality choices to update a local preview. Examples visibly disclose that no task, account access or message is real. They do not imply end-to-end encryption or an independent computer for each assistant. The sidecar uses inline SVG and live semantic variables for its static scene preview; no raster asset or icon font is required.

## Do's and Don'ts

### Do:

- **Do** reuse semantic CSS variables so light and dark modes remain paired.
- **Do** use the shared Button, Field, Badge, Card and navigation components for workspace screens.
- **Do** keep public examples readable without playback, with the same companion identity across changing examples.
- **Do** retain visible keyboard focus, continuous story playback and readable reduced-motion alternatives in public stories.
- **Do** keep illustrative scene interactions local and retain current-versus-future qualifiers beside the experience they qualify.

### Don't:

- **Don’t** replace the incumbent sage, paper and ink-dark identity with an unrelated palette.
- **Don’t** use subtle foreground for essential text; the source explicitly reserves it for placeholders and disabled content.
- **Don’t** turn the landing’s story sequence or companion-scene compositions into an application-wide layout rule.
- **Don’t** treat the public page’s open bands as a prohibition on the workspace’s existing cards.


The landing story v2 replaces the earlier cycling scenes with five product-native scenes: continuity (one memory across surfaces), memory inspection, a permission/provider boundary, a useful plan artifact, and multiple companions with a local creation preview. Motion is anime.js-driven: hero word and card assembly, scroll-scrubbed drift and reveals, toggle/plan/companion component motion and calm loops; reduced motion shows complete stills.
