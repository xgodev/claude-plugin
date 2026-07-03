---
name: web-core
description: Use when choosing colors, palettes, visual styles, typography/font pairings, chart types, icons, or UX guidelines for any web or mobile UI — a searchable, framework-agnostic design catalog (161 palettes, 85 styles, font pairings, chart types, 99 UX do/don'ts) queried via a BM25 search engine. Also for generating a coherent design system for a product/page.
---

# web-core — catálogo de design + engine de busca

Dados de design UI/UX **framework-agnósticos**, consultados por um script de busca
BM25. Os CSVs **não entram no contexto** — você consulta e lê só o topo do
resultado. As skills por framework (`web-react`, `web-vue`, …) remetem a esta.

## When to use
- Escolher **paleta/cor**, **estilo** visual, **pareamento de fontes**, **tipo de gráfico**, **ícones**.
- Checar **UX guidelines** (do/don't com exemplo de código + severidade).
- Gerar um **design system** inicial coerente para um produto/tela.
- **Skip:** lógica de backend; qualquer coisa sem decisão de UI.

## Como consultar
Rode o engine (os dados são resolvidos relativos ao script — rode de qualquer cwd):

```bash
python3 skills/web-core/scripts/search.py "<query>" --domain <domain> [--max-results N]
python3 skills/web-core/scripts/search.py "<query>" --stack <stack>
python3 skills/web-core/scripts/search.py "<query>" --design-system -p "Projeto" [--persist --page "dashboard"]
```

- **domains:** `style`, `color`, `chart`, `landing`, `product`, `ux`, `typography`, `icons`
- **stacks:** `react`, `nextjs`, `vue`, `svelte`, `astro`, `swiftui`, `react-native`, `flutter`, `nuxtjs`, `nuxt-ui`, `html-tailwind`, `shadcn`, `jetpack-compose`, `threejs`, `angular`, `laravel`, `javafx`
- `--design-system` monta paleta + estilo + tipografia coerentes para o produto; `--persist` grava em `design-system/MASTER.md` (+ overrides por página).

## Dados (em `data/`)
`colors` (161 paletas com slots semânticos + contraste WCAG), `styles` (85),
`typography`/`google-fonts` (pareamentos + import/URL), `charts` (seleção + a11y),
`ux-guidelines` (99 do/don't), `ui-reasoning` (produto → recomendação),
`products`, `icons`, `landing`, e `stacks/*.csv` (por framework).

## Common mistakes
| Erro | Certo |
|---|---|
| `cat` dos CSV pro contexto | consultar via `search.py` (BM25 retorna só o topo) |
| inventar paleta/estilo | puxar do catálogo (paletas já vêm ajustadas p/ WCAG) |
| carregar todos os stacks | usar `--stack <fw>` só do framework do projeto |
