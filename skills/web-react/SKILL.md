---
name: web-react
description: Use when building or reviewing UI in React, Next.js, or shadcn/ui — component and style/token patterns for these stacks. Entry point that routes to the web-core design catalog.
---

# web-react — design para React / Next.js / shadcn

Ponto de entrada por framework. Os dados vivem no **`web-core`** (catálogo + engine);
esta skill só roteia para os stacks de React.

**REQUIRED BACKGROUND:** use a skill **`web-core`** para o catálogo agnóstico
(paletas, estilos, tipografia, UX, charts) e para gerar design system.

## Uso
```bash
python3 skills/web-core/scripts/search.py "<query>" --stack react
python3 skills/web-core/scripts/search.py "<query>" --stack nextjs
python3 skills/web-core/scripts/search.py "<query>" --stack shadcn
```
Para cor/estilo/fonte/UX (agnóstico), use os `--domain` do `web-core`.
