---
name: web-vue
description: Use when building or reviewing UI in Vue, Nuxt, or Nuxt UI — component and style/token patterns for these stacks. Entry point that routes to the web-core design catalog.
---

# web-vue — design para Vue / Nuxt / Nuxt UI

Ponto de entrada por framework. Os dados vivem no **`web-core`** (catálogo + engine);
esta skill só roteia para os stacks de Vue.

**REQUIRED BACKGROUND:** use a skill **`web-core`** para o catálogo agnóstico
(paletas, estilos, tipografia, UX, charts) e para gerar design system.

## Uso
```bash
python3 skills/web-core/scripts/search.py "<query>" --stack vue
python3 skills/web-core/scripts/search.py "<query>" --stack nuxtjs
python3 skills/web-core/scripts/search.py "<query>" --stack nuxt-ui
```
Para cor/estilo/fonte/UX (agnóstico), use os `--domain` do `web-core`.
