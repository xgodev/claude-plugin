---
name: ux-ui
description: "Use for any UI/UX design work on web or mobile: choosing colors, palettes, visual styles, typography/fonts, charts, and icons; component/layout patterns per framework (React, Vue, Svelte, Next, Nuxt, Tailwind, SwiftUI, Flutter, React Native, Jetpack Compose, Angular, Astro, Three.js, Laravel, JavaFX); plus UX heuristics, accessibility, design systems, motion, states, research, and metrics. The design door for the xgodev stack."
license: MIT
metadata:
  author: jpfaria
  version: "1.0.0"
---

Index for UI/UX design. Two tools: (1) a **searchable catalog** (engine +
data) for concrete choices -- palettes, styles, fonts, charts, per-framework
patterns; (2) **methodology references** for judgment -- heuristics, a11y,
design systems, etc. Read the row that matches, then the leaf it points to.
Paths are relative to this directory (`skills/ux-ui/`). Catalog data is
**never loaded into context** -- it is queried through the script.

## Catalog -- concrete data (via the engine)

```bash
python3 skills/ux-ui/scripts/search.py "<query>" <flag>
```

| I need... | Flag |
|---|---|
| palette / color | `--domain color` |
| visual style | `--domain style` |
| typography / font pairing | `--domain typography` |
| graph / chart | `--domain chart` |
| UX do/don't | `--domain ux` |
| icons | `--domain icons` |
| landing / product | `--domain landing` · `--domain product` |
| patterns for a **framework** | `--stack <s>` |
| coherent **design system** from scratch | `--design-system -p "Project"` (`--persist` writes to `design-system/`) |

Stacks: `react`, `nextjs`, `vue`, `svelte`, `astro`, `swiftui`, `react-native`, `flutter`, `nuxtjs`, `nuxt-ui`, `html-tailwind`, `shadcn`, `jetpack-compose`, `threejs`, `angular`, `laravel`, `javafx`.

## Methodology -- judgment (read the leaf)

| Context | Reference |
|---|---|
| Usability heuristics (NNG) | `references/heuristics.md` |
| Accessibility / WCAG / inclusive | `references/a11y.md` |
| Design systems / tokens / architecture | `references/design-systems.md` |
| Visual system (type / color / spacing / hierarchy) | `references/visual.md` |
| Components + code (React / SwiftUI / CSS) | `references/components.md` |
| Interaction / motion / animation | `references/motion.md` |
| States (loading / empty / error / skeleton) | `references/states.md` |
| Mobile UX (touch / iOS / Android) | `references/mobile.md` |
| Desktop / enterprise / data-dense | `references/desktop.md` |
| Cognitive psychology / Laws of UX / Gestalt | `references/cognitive.md` |
| UX research (tests / interviews / surveys) | `references/research.md` |
| UX metrics (HEART / SUS / analytics) | `references/metrics.md` |
| Ethics / dark patterns / content strategy | `references/ethics.md` |
| i18n / RTL / cross-cultural | `references/i18n.md` |
| Design critique (Lerman / case studies) | `references/critique.md` |
| Figma / Dev Mode / design-to-code | `references/figma.md` |
| Agentic AI / generative UX / RAG UI | `references/agentic.md` |
| Spatial / voice / multimodal AI (AR/VR) | `references/spatial.md` |
| Ambient / calm / zero-UI | `references/ambient.md` |
