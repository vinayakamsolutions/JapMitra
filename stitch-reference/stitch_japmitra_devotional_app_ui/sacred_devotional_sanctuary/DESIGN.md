---
name: Sacred Devotional Sanctuary
colors:
  surface: '#fff8f5'
  surface-dim: '#f0d5c3'
  surface-bright: '#fff8f5'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fff1e9'
  surface-container: '#ffeadd'
  surface-container-high: '#ffe3d1'
  surface-container-highest: '#f9ddcc'
  on-surface: '#27180e'
  on-surface-variant: '#4e4637'
  inverse-surface: '#3d2d21'
  inverse-on-surface: '#ffede3'
  outline: '#807665'
  outline-variant: '#d2c5b1'
  surface-tint: '#7a5900'
  primary: '#7a5900'
  on-primary: '#ffffff'
  primary-container: '#c59b3f'
  on-primary-container: '#493400'
  inverse-primary: '#eec060'
  secondary: '#a43d00'
  on-secondary: '#ffffff'
  secondary-container: '#ff793a'
  on-secondary-container: '#642200'
  tertiary: '#725948'
  on-tertiary: '#ffffff'
  tertiary-container: '#b99b87'
  on-tertiary-container: '#483324'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdea1'
  primary-fixed-dim: '#eec060'
  on-primary-fixed: '#261900'
  on-primary-fixed-variant: '#5c4300'
  secondary-fixed: '#ffdbcd'
  secondary-fixed-dim: '#ffb597'
  on-secondary-fixed: '#360f00'
  on-secondary-fixed-variant: '#7d2d00'
  tertiary-fixed: '#fedcc6'
  tertiary-fixed-dim: '#e1c0ab'
  on-tertiary-fixed: '#29180a'
  on-tertiary-fixed-variant: '#594232'
  background: '#fff8f5'
  on-background: '#27180e'
  surface-variant: '#f9ddcc'
typography:
  headline-xl:
    fontFamily: EB Garamond
    fontSize: 36px
    fontWeight: '600'
    lineHeight: 44px
  headline-xl-mobile:
    fontFamily: EB Garamond
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-lg:
    fontFamily: EB Garamond
    fontSize: 26px
    fontWeight: '500'
    lineHeight: 34px
  headline-md:
    fontFamily: EB Garamond
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  title-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.25rem
---

## Brand & Style

This design system crafts a meditative, regal spiritual sanctuary tailored for modern devotional practice. It intentionally departs from gaudy temple calendars, neon saffron tones, and cluttered iconography. Instead, it reinterprets timeless Vedic dignity through quiet luxury, architectural clarity, and meditative stillness.

The visual style blends soft organic pillular forms with classical editorial cadence. Pristine warm ivory paper surfaces mimic aged parchment and temple sanctum marble, complemented by deep terracotta sacred embers and antique gold filigree highlights. The interface evokes peace, introspective focus, reverence, and daily ritual continuity without visual fatigue.

## Colors

The palette draws strictly from sanctum textures: brass lamps, pressed terracotta pottery, unbleached cotton, and sandalwood paste.

- **Primary (`#C59B3F` - Antique Muted Gold):** Reserved for devotional accents, active prayer counters, circular mala ring beads, active tabs, subtle border outlines, and consecrated milestone medals.
- **Secondary (`#D95D1E` - Restrained Deep Saffron / Terracotta):** Denotes vital spiritual actions (e.g., *Sankalpa*, Starting a Japa session, confirming offerings). Never applied in wide fluorescent fills; used selectively for grounding and energy.
- **Tertiary (`#5C4535` - Warm Umber):** Guides secondary structural labels, timestamps, metadata, and supporting iconography.
- **Neutral Backgrounds & Canvas:**
  - Base Background: `#FDFBF7` (Sacred Cream Canvas)
  - Surface Default: `#FAF6EE` (Warm Ivory Sheet)
  - Surface Elevated / Card Fill: `#FFFFFF` or `#F3ECE1`
- **Neutral Foreground & Body:** `#2E1F14` (Deep Warm Espresso) provides natural ink-like legibility superior to harsh pure black, pairing seamlessly with both Latin and Devanagari letterforms.

## Typography

Typography bridges scholarly scripture and effortless modern digital interaction:

- **EB Garamond** acts as the primary classical voice for shlokas, mantra titles, chapter headings, and celebration displays. Its high x-height and classical balance honor traditional typesetting.
- **Plus Jakarta Sans** grounds the application with geometric legibility across counts, settings, navigation, and long-form commentaries.
- **Devanagari Harmony:** Font pairings must retain comfortable baseline alignment when switching between Hindi, Sanskrit, and English scripts. Avoid cramped leading; prayers and shlokas require generous line height (`1.6` to `1.75`) to allow diacritics and matras to breathe clearly.

## Layout & Spacing

The layout is built for hand-held Android devotional engagement (portrait orientation prioritized for single-thumb prayer chanting and rosary bead tracking):

- **Grid & Margins:** A continuous fluid grid with an outer screen margin of `1.25rem` (20px) on mobile viewports. On larger foldable or tablet viewports, the margin expands to `2rem`, clamping maximum content width to `640px` to maintain focused meditation sessions without visual drift.
- **Rhythm & Empty Space:** Breathing room is an active spiritual element. High-density screens are avoided. Each section, mantra card, and bead counter is enveloped by minimum `space-lg` to encourage stillness and focus.
- **Thumb Zone Safety:** The interactive prayer trigger and mala wheel center within the comfortable lower 60% of the screen height, while shloka text remains gently elevated in the focal center.

## Elevation & Depth

Visual hierarchy reflects the calm layering of temple architecture:

- **Surface Tiers:**
  - Base: `#FDFBF7` (Canvas foundation)
  - Surface Level 1 (Cards, sheets): `#FFFFFF` or `#FAF6EE` with hairline borders of `1px solid rgba(197, 155, 63, 0.22)`.
  - Surface Level 2 (Floating modals, active chanting rings): `#FFFFFF` accompanied by warm amber diffusion.
- **Ambient Shadow Character:** Pure neutral black shadows are forbidden. All elevation relies on ultra-soft, warm umber and terracotta shadows:
  - Low Elevation: `0px 2px 8px rgba(46, 31, 20, 0.04), 0px 1px 3px rgba(197, 155, 63, 0.08)`
  - Medium Elevation: `0px 8px 24px rgba(92, 69, 53, 0.07), 0px 2px 6px rgba(197, 155, 63, 0.12)`
  - Elevated / Interactive: `0px 14px 36px rgba(92, 69, 53, 0.10), 0px 4px 12px rgba(217, 93, 30, 0.08)`
- **Atmospheric Depth:** Soft radial gradients originating from the primary gold tone at 3-5% opacity simulate morning sunlight (*Brahma Muhurta*) bathing the screen.

## Shapes

The shape system adopts a pure pillular geometry (roundedness level 3):

- **Base Radius (`rounded-md`):** `1rem` (16px) applied to small notification badges and input controls.
- **Card & Surface Radius (`rounded-lg`):** `1.5rem` to `2rem` (24px to 32px), creating smooth, pebble-like devotional surfaces resembling polished river stones.
- **Pill Radius (`rounded-full`):** Full organic curvature applied to primary buttons, interactive tags, streak pills, and category toggles.
- **Mala & Counter Circles:** Perfect circular vessels (`50%` radius) reserved for japa progress indicators, lotus mandalas, and daily count tracking dials.

## Components

### Buttons & Interactive Controls
- **Primary Sacred Action:** Full pill button with terracotta fill (`#D95D1E`), crisp white text, and a micro-glow of antique gold on press. Height: 52px for ergonomic thumb tapping during japa.
- **Secondary Ritual Action:** Warm ivory fill (`#FAF6EE`), bordered with 1px antique gold (`#C59B3F` at 40%), text in deep espresso (`#2E1F14`).
- **Devotional Chanting Trigger (Japa Tap Surface):** Circular pill or wide card surface emitting a subtle golden wave ripple on each mantra completion, providing immediate haptic and visual reassurance.

### Chips & Sacred Tags
- Full pill contour with subtle warm ivory tint, framed with delicate `rgba(197, 155, 63, 0.3)` strokes.
- Active chips take an antique gold fill (`#C59B3F`) with crisp espresso text, signaling active deity or prayer categories (e.g., *Shiva*, *Gayatri*, *Krishna*, *Niyama*).

### Cards & Reading Vessels
- Contained within `24px` rounded radii, tinted in `#FAF6EE` over the `#FDFBF7` canvas.
- Framed with an antique muted gold hairline outline (`rgba(197, 155, 63, 0.25)`).
- Interior padding set strictly to `1.5rem` (`space-lg`), separating Sanskrit original verses from vernacular translations cleanly.

### Lists & Chant History
- Borderless list rows separated by delicate hairline dividers tinted in umber at 8% opacity (`rgba(92, 69, 53, 0.08)`).
- Left accessory features a soft pill icon container holding 1.75px stroked ritual outlines (diya, conch, lotus, mala beads).

### Input Fields & Search
- Rounded pill form (height: 48px) in pure white with a calm `1px solid rgba(197, 155, 63, 0.25)` outline.
- Active focus smoothly transitions the outline to full antique gold (`#C59B3F`) with a faint 3px warm aura glow.

### Specialized Component: The Japa Tracker Dial
- Concentric 108-bead indicator rendered in subdued gold wireframes (`1.75px` stroke).
- Completed chants fill beads progressively with warm terracotta embers (`#D95D1E`), keeping the UI calming, sacred, and distraction-free.