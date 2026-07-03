# ux-ui — a skill-porta de design

Design UI/UX absorvido do `ui-ux-pro-max` + `ux-ui-mastery`, consolidado numa
**única skill-porta** `ux-ui`, no mesmo molde da `boost` (SKILL.md = índice que
roteia; conteúdo pesado nas leaves/engine).

## Estrutura (`skills/ux-ui/`)

- **`SKILL.md`** — a porta: uma tabela roteia por **catálogo** (flags do engine) e
  outra por **metodologia** (`references/*.md`).
- **`scripts/`** — engine de busca BM25 (`search.py` + `core.py` + `design_system.py`).
- **`data/`** — catálogo: paletas, estilos, tipografia, charts, ux-guidelines,
  ui-reasoning, icons, products, landing + `data/stacks/*.csv` (17 frameworks).
  **Não entra no contexto** — consultado pelo script.
- **`references/`** — 19 leaves de metodologia (nomes curtos: `heuristics`, `a11y`,
  `design-systems`, `visual`, `components`, `motion`, `states`, `mobile`, `desktop`,
  `cognitive`, `research`, `metrics`, `ethics`, `i18n`, `critique`, `figma`,
  `agentic`, `spatial`, `ambient`), migradas do fork `ux-ui-mastery`.

## Por que uma porta só

Igual `boost`: um índice enxuto que o agente lê e então salta pra leaf/engine
certo — em vez de dezenas de skills concorrendo na lista. O engine resolve os
dados relativos a si (`DATA_DIR = scripts/../data`), então tudo mora junto.

## Origem e follow-up

- Catálogo + engine: `ui-ux-pro-max` (histórico do repo Laudo, commit `ea43b57`).
- Metodologia (`references/`): fork `xgodev/ux-ui-mastery`.
- Com isso a entrada `ux-ui-mastery` sai do `marketplace.json` e o fork é arquivado.
- Refino futuro: revisar as leaves de metodologia (foram migradas as-is) e
  descrições por leaf; ajustar `references/*` que citem paths do fork.
