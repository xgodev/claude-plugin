---
name: ux-ui
description: "Use for any UI/UX design work on web or mobile: choosing colors, palettes, visual styles, typography/fonts, charts, and icons; component/layout patterns per framework (React, Vue, Svelte, Next, Nuxt, Tailwind, SwiftUI, Flutter, React Native, Jetpack Compose, Angular, Astro, Three.js, Laravel, JavaFX); plus UX heuristics, accessibility, design systems, motion, states, research, and metrics. The design door for the xgodev stack."
license: MIT
metadata:
  author: jpfaria
  version: "1.0.0"
---

Index for UI/UX design. Duas ferramentas: (1) um **catálogo pesquisável** (engine + dados) para escolhas concretas — paletas, estilos, fontes, charts, padrões por framework; (2) **references de metodologia** para julgamento — heurísticas, a11y, design systems, etc. Leia a linha que casa, depois a leaf que ela aponta. Paths relativos a este diretório (`skills/ux-ui/`). Os dados do catálogo **não entram no contexto** — são consultados pelo script.

## Catálogo — dados concretos (via engine)

```bash
python3 skills/ux-ui/scripts/search.py "<query>" <flag>
```

| Preciso de… | Flag |
|---|---|
| paleta / cor | `--domain color` |
| estilo visual | `--domain style` |
| tipografia / pareamento de fontes | `--domain typography` |
| gráfico / chart | `--domain chart` |
| UX do/don't | `--domain ux` |
| ícones | `--domain icons` |
| landing / product | `--domain landing` · `--domain product` |
| padrões de um **framework** | `--stack <s>` |
| **design system** coerente do zero | `--design-system -p "Projeto"` (`--persist` grava em `design-system/`) |

Stacks: `react`, `nextjs`, `vue`, `svelte`, `astro`, `swiftui`, `react-native`, `flutter`, `nuxtjs`, `nuxt-ui`, `html-tailwind`, `shadcn`, `jetpack-compose`, `threejs`, `angular`, `laravel`, `javafx`.

## Metodologia — julgamento (leia a leaf)

| Contexto | Reference |
|---|---|
| Heurísticas de usabilidade (NNG) | `references/heuristics.md` |
| Acessibilidade / WCAG / inclusivo | `references/a11y.md` |
| Design systems / tokens / arquitetura | `references/design-systems.md` |
| Sistema visual (tipo / cor / spacing / hierarquia) | `references/visual.md` |
| Componentes + código (React / SwiftUI / CSS) | `references/components.md` |
| Interação / motion / animação | `references/motion.md` |
| Estados (loading / empty / error / skeleton) | `references/states.md` |
| Mobile UX (touch / iOS / Android) | `references/mobile.md` |
| Desktop / enterprise / data-dense | `references/desktop.md` |
| Psicologia cognitiva / Laws of UX / Gestalt | `references/cognitive.md` |
| Pesquisa UX (testes / entrevistas / survey) | `references/research.md` |
| Métricas UX (HEART / SUS / analytics) | `references/metrics.md` |
| Ética / dark patterns / content strategy | `references/ethics.md` |
| i18n / RTL / cross-cultural | `references/i18n.md` |
| Crítica de design (Lerman / case studies) | `references/critique.md` |
| Figma / Dev Mode / design-to-code | `references/figma.md` |
| AI agêntico / generative UX / RAG UI | `references/agentic.md` |
| AI espacial / voz / multimodal (AR/VR) | `references/spatial.md` |
| Ambient / calm / zero-UI | `references/ambient.md` |
