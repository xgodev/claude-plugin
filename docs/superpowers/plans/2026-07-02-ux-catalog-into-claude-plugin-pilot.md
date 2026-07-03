# UX Catalog into claude-plugin (Pilot) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every new `SKILL.md` is authored via **superpowers:writing-skills** (RED baseline first) — this plan says WHAT skill and WHERE; the skill body is produced under that gate at execution time.

**Goal:** Absorver o catálogo de design web (do `ui-ux-pro-max`) para dentro do plugin all-in-one `xgodev/claude-plugin`, quebrado em **skills por framework** sobre um **core** compartilhado — começando por um piloto (`web-core` + `web-react` + `web-vue`) que já é útil sozinho.

**Architecture:** Um "cérebro" (`web-core`) carrega os dados stack-agnósticos (paletas, estilos, tipografia, ux-guidelines, charts, ui-reasoning) + o motor de busca em Python. Cada skill de framework (`web-react`, `web-vue`, …) é fina: carrega o CSV do seu stack e **remete ao `web-core`** (cross-reference, sem duplicar dados). Assim um projeto Vue carrega só `web-vue` + `web-core`, não o catálogo React inteiro.

**Tech Stack:** Claude Code skills (SKILL.md + data CSV + Python scripts). Fonte dos dados: commit `ea43b57` do repo Laudo (`~/Projetos/bitbucket.org/unaprosil/laudo`), path `.claude/skills/ui-ux-pro-max/`. Repo alvo: `~/Projetos/github.com/xgodev/claude-plugin` (remote `git@github.com:xgodev/claude-plugin.git`).

## Global Constraints

- **Editar no repo-fonte, nunca no cache** (`~/.claude/plugins/cache/...` é read-only na prática; LAW 10 do dev-rules).
- **Cada `SKILL.md` novo passa por `superpowers:writing-skills`** (RED baseline → GREEN → REFACTOR). Sem baseline, sem skill.
- **Nomes de skill:** só letras/números/hífen, verb-first/descritivos. Framework skills: `web-react`, `web-vue` (não `web-vuejs`).
- **`description` = só quando usar** (triggers), nunca resume o workflow (SDO da writing-skills).
- **DRY:** dados stack-agnósticos vivem SÓ no `web-core`; framework skills referenciam, não copiam.
- **Não renomear o plugin** `claude-plugin` nem quebrar `enabledPlugins` existentes.
- Fora de escopo deste plano (vira plano próprio): migrar as 19 skills de metodologia do fork `xgodev/ux-ui-mastery`; frameworks além de react/vue; remover a entrada `ux-ui-mastery` do `marketplace.json` e aposentar o fork (só depois que metodologia + frameworks estiverem migrados).

---

## File Structure

- `skills/web-core/SKILL.md` — overview + como consultar os dados/engine.
- `skills/web-core/data/*.csv` — colors, styles, typography, ux-guidelines, charts, ui-reasoning, icons, products (stack-agnósticos).
- `skills/web-core/scripts/*.py` — motor de busca (core.py, search.py, design_system.py).
- `skills/web-react/SKILL.md` + `skills/web-react/data/react.csv` (+ shadcn.csv, nextjs.csv).
- `skills/web-vue/SKILL.md` + `skills/web-vue/data/vue.csv` (+ nuxtjs.csv, nuxt-ui.csv).
- `docs/ux-catalog.md` — doc de referência do subsistema (índice das skills web-*).
- `CHANGELOG.md` — entrada da adição.

---

### Task 1: `web-core` — dados + engine compartilhados

**Files:**
- Create: `skills/web-core/data/{colors,styles,typography,ux-guidelines,charts,ui-reasoning,icons,products}.csv`
- Create: `skills/web-core/scripts/{core,search,design_system}.py`
- Create: `skills/web-core/SKILL.md`
- Test: baseline via subagente (writing-skills), sem arquivo de teste em disco.

**Interfaces:**
- Produces: o namespace de dados que `web-react`/`web-vue` referenciam ("consulte `web-core` para paletas/estilos/tipografia"). Comando de busca: `python skills/web-core/scripts/search.py <query>` (confirmar assinatura real ao extrair).

- [ ] **Step 1: Extrair os dados stack-agnósticos do histórico do Laudo**

```bash
cd ~/Projetos/github.com/xgodev/claude-plugin
mkdir -p skills/web-core/data skills/web-core/scripts
LAUDO=~/Projetos/bitbucket.org/unaprosil/laudo
for f in colors styles typography ux-guidelines charts ui-reasoning icons products; do
  git -C "$LAUDO" show ea43b57:.claude/skills/ui-ux-pro-max/data/$f.csv > skills/web-core/data/$f.csv
done
for s in core search design_system; do
  git -C "$LAUDO" show ea43b57:.claude/skills/ui-ux-pro-max/scripts/$s.py > skills/web-core/scripts/$s.py
done
```

- [ ] **Step 2: Verificar que os arquivos vieram íntegros**

```bash
wc -l skills/web-core/data/*.csv         # colors≈161, styles≈85, ux-guidelines≈99, ui-reasoning≈162
python3 -c "import ast,sys; [ast.parse(open(f).read()) for f in ['skills/web-core/scripts/core.py','skills/web-core/scripts/search.py','skills/web-core/scripts/design_system.py']]; print('py ok')"
```
Expected: contagens plausíveis + `py ok` (sem SyntaxError). Ajustar os scripts para os paths novos se referenciarem `data/` relativo.

- [ ] **Step 3: Autorar `skills/web-core/SKILL.md` via writing-skills**

RED baseline: dispatch subagente para "escolher paleta + estilo + tipografia para um dashboard SaaS" SEM a skill; documentar o que ele erra/inventa. GREEN: SKILL.md com `name: web-core`, `description: Use when choosing colors, palettes, styles, typography, charts, or UX guidelines for any web/mobile UI (framework-agnostic reference + searchable data)`, overview do dataset + como rodar `search.py`. REFACTOR até fechar. (Reference skill → teste = cenário de retrieval, não pressão.)

- [ ] **Step 4: Verificar retrieval WITH skill**

Dispatch subagente com a skill presente na mesma tarefa; confirmar que ele acha a paleta certa via `web-core` e cita o dado, não inventa.

- [ ] **Step 5: Commit**

```bash
git add skills/web-core
git commit -m "feat(web-core): catálogo de design stack-agnóstico + engine (de ui-ux-pro-max)"
```

---

### Task 2: `web-react` — skill fina sobre o core

**Files:**
- Create: `skills/web-react/data/{react,shadcn,nextjs}.csv`
- Create: `skills/web-react/SKILL.md`

**Interfaces:**
- Consumes: `web-core` (referência a paletas/estilos/tipografia — não duplica).
- Produces: guia React/Next/shadcn que aponta pro core.

- [ ] **Step 1: Extrair os CSVs de stack React**

```bash
cd ~/Projetos/github.com/xgodev/claude-plugin
mkdir -p skills/web-react/data
LAUDO=~/Projetos/bitbucket.org/unaprosil/laudo
for f in react shadcn nextjs; do
  git -C "$LAUDO" show ea43b57:.claude/skills/ui-ux-pro-max/data/stacks/$f.csv > skills/web-react/data/$f.csv
done
wc -l skills/web-react/data/*.csv
```
Expected: react≈54, shadcn≈61, nextjs≈53 linhas.

- [ ] **Step 2: Autorar `skills/web-react/SKILL.md` via writing-skills**

RED baseline: subagente "montar um componente React/shadcn com bom design" SEM a skill. GREEN: `name: web-react`, `description: Use when building or reviewing UI in React, Next.js, or shadcn/ui — component patterns, style/token choices for these stacks`. Corpo: como usar os CSVs de react/shadcn/nextjs **+ `**REQUIRED BACKGROUND:** consulte a skill web-core** para paletas/estilos/tipografia** (cross-ref, sem repetir dados). REFACTOR.

- [ ] **Step 3: Verificar WITH skill**

Subagente com skill: confirma que ele carrega `web-react` E remete ao `web-core` pros dados agnósticos (não re-inventa paleta).

- [ ] **Step 4: Commit**

```bash
git add skills/web-react
git commit -m "feat(web-react): guia de design React/Next/shadcn sobre o web-core"
```

---

### Task 3: `web-vue` — skill fina sobre o core

**Files:**
- Create: `skills/web-vue/data/{vue,nuxtjs,nuxt-ui}.csv`
- Create: `skills/web-vue/SKILL.md`

**Interfaces:**
- Consumes: `web-core`. Produces: guia Vue/Nuxt.

- [ ] **Step 1: Extrair os CSVs de stack Vue**

```bash
cd ~/Projetos/github.com/xgodev/claude-plugin
mkdir -p skills/web-vue/data
LAUDO=~/Projetos/bitbucket.org/unaprosil/laudo
for f in vue nuxtjs nuxt-ui; do
  git -C "$LAUDO" show ea43b57:.claude/skills/ui-ux-pro-max/data/stacks/$f.csv > skills/web-vue/data/$f.csv
done
wc -l skills/web-vue/data/*.csv
```
Expected: vue≈50, nuxtjs≈59, nuxt-ui≈71 linhas.

- [ ] **Step 2: Autorar `skills/web-vue/SKILL.md` via writing-skills**

RED baseline: subagente "montar um componente Vue/Nuxt com bom design" SEM a skill. GREEN: `name: web-vue`, `description: Use when building or reviewing UI in Vue, Nuxt, or Nuxt UI — component patterns and style/token choices for these stacks`. Corpo espelha `web-react`: CSVs vue/nuxt + `**REQUIRED BACKGROUND:** web-core`. REFACTOR.

- [ ] **Step 3: Verificar WITH skill** (igual Task 2 Step 3, para Vue).

- [ ] **Step 4: Commit**

```bash
git add skills/web-vue
git commit -m "feat(web-vue): guia de design Vue/Nuxt sobre o web-core"
```

---

### Task 4: Wiring — doc do subsistema + CHANGELOG

**Files:**
- Create: `docs/ux-catalog.md`
- Modify: `CHANGELOG.md` (topo)

Nota: **não** mexer em `marketplace.json`/`plugin.json` neste piloto — as skills novas em `skills/` já são descobertas pelo plugin `source: ./`. A remoção da entrada `ux-ui-mastery` e a aposentadoria do fork ficam para o plano de migração da metodologia (quando o fork estiver 100% absorvido).

- [ ] **Step 1: Escrever `docs/ux-catalog.md`**

Índice do subsistema: o modelo `web-core` (dados) + framework skills (`web-react`, `web-vue`, e a lista dos que virão), a regra DRY (dados só no core), e como adicionar um novo framework (extrair `stacks/<fw>.csv` → skill fina que remete ao core).

- [ ] **Step 2: Adicionar entrada no CHANGELOG**

```markdown
## [Unreleased]
### Added
- Catálogo de design web como skills por framework sobre um `web-core` compartilhado (piloto: web-core, web-react, web-vue). Origem: ui-ux-pro-max.
```

- [ ] **Step 3: Commit**

```bash
git add docs/ux-catalog.md CHANGELOG.md
git commit -m "docs(ux-catalog): índice do subsistema de design web + changelog"
```

---

## Follow-on (planos separados — fora deste piloto)

1. **Migrar as 19 skills de metodologia** do fork `xgodev/ux-ui-mastery` para `skills/` (accessibility-inclusive-design, nng-ux-heuristics, ux-research-methods, design-systems-architecture, …). Cada uma revisada, não só copiada.
2. **Frameworks restantes:** `web-svelte`, `web-nextjs` (se separar do react), `web-tailwind`, `web-angular`, `web-astro`, `web-threejs`; `mobile-flutter`, `mobile-swiftui`, `mobile-react-native`, `mobile-jetpack-compose`; `desktop-javafx`; `laravel`.
3. **Retirar a dependência:** remover a entrada `ux-ui-mastery` do `marketplace.json`, atualizar `plugin.json`/README, e **arquivar o repo** `xgodev/ux-ui-mastery` — só após 1 e 2 completos.

## Self-Review

- **Cobertura:** piloto = web-core + web-react + web-vue + doc/changelog. Migração de metodologia e demais frameworks explicitamente diferidos (follow-on). ✓
- **Placeholders:** comandos de extração são concretos (git show por arquivo); a autoria de cada SKILL.md é delegada ao gate writing-skills (RED baseline nomeado por task) — não é placeholder, é o processo correto para skill. ✓
- **Consistência:** framework skills sempre `**REQUIRED BACKGROUND:** web-core`; dados só no core (DRY). Nomes `web-core`/`web-react`/`web-vue` usados de forma consistente. ✓
