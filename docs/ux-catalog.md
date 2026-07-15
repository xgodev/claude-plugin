# ux-ui -- the design skill

UI/UX design capability owned by the **`ux-ui` skill**, in the same shape
as `boost`: the SKILL.md routes to a small index; the heavy content lives
in leaves and a search engine. The `dev` door cross-references it for
design done mid-feature.

## Structure (`skills/ux-ui/`)

- **`index.md`** -- the leaf's own index: one table routes by **catalog**
  (engine flags), another by **methodology** (`references/*.md`).
- **`scripts/`** -- BM25 search engine (`search.py` + `core.py` +
  `design_system.py`).
- **`data/`** -- the catalog: palettes, styles, typography, charts,
  UX guidelines, UI reasoning, icons, products, landing patterns +
  `data/stacks/*.csv` (17 frameworks). **Never loaded into context** --
  queried through the script.
- **`references/`** -- 19 methodology leaves (short names: `heuristics`,
  `a11y`, `design-systems`, `visual`, `components`, `motion`, `states`,
  `mobile`, `desktop`, `cognitive`, `research`, `metrics`, `ethics`,
  `i18n`, `critique`, `figma`, `agentic`, `spatial`, `ambient`).

## Why a single door

Same reasoning as `boost`: one lean index the agent reads, then jumps to
the right leaf or engine call -- instead of dozens of skills competing in
the skills list. The engine resolves its data relative to itself
(`DATA_DIR = scripts/../data`), so everything lives together.

## Follow-up

- Review the methodology leaves (migrated as-is) and their per-leaf
  descriptions; fix any `references/*` that cite paths from their
  pre-consolidation layout.
