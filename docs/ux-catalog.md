# UX Catalog — skills de design web

Catálogo de design UI/UX absorvido do `ui-ux-pro-max`, organizado como um **core
compartilhado** + **skills finas por framework**.

## Arquitetura

- **`web-core`** — a ferramenta: engine de busca BM25 (`scripts/search.py`) +
  todos os dados (`data/`): paletas, estilos, tipografia, charts, ux-guidelines,
  ui-reasoning, icons, products, landing, e `data/stacks/*.csv` por framework.
  Os dados **não entram no contexto** — são consultados pelo script.
- **skills por framework** (`web-react`, `web-vue`, …) — ponteiros finos que
  roteiam para `web-core --stack <fw>` e remetem ao `web-core` para o catálogo
  agnóstico. **Não carregam dados próprios** (DRY: dado só no core).

## Por que assim

O engine resolve os dados relativos a si (`DATA_DIR = scripts/../data`) e o
`--stack` lê `data/stacks/<fw>.csv`. Separar os CSVs de stack em skills diferentes
quebraria a busca. Então o dado fica todo no `web-core`; as skills de framework
existem para **descoberta** (a SKILL.md certa aparece pro projeto certo) e
**roteamento** (o `--stack` correto).

## Adicionar um novo framework

1. Confirmar que `web-core/data/stacks/<fw>.csv` existe (todos os 17 stacks já vieram).
2. Criar `skills/web-<fw>/SKILL.md` fino: `description` = "Use when building/reviewing
   UI in <fw>"; corpo remete ao `web-core` (`**REQUIRED BACKGROUND:** web-core`) e
   dá os comandos `--stack <fw>`. Sem `data/` próprio.
3. Autorar via `superpowers:writing-skills` (baseline de retrieval).

## Estado

- **Piloto entregue:** `web-core`, `web-react`, `web-vue`.
- **Follow-on:** demais frameworks (`web-svelte`, `web-tailwind`, `mobile-flutter`,
  `mobile-swiftui`, …); migração das 19 skills de metodologia do fork
  `xgodev/ux-ui-mastery`; depois remover a dep `ux-ui-mastery` do `marketplace.json`
  e arquivar o fork.
