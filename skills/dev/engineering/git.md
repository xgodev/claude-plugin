# Git -- branching, merging, releases, versions

Read before the first git command of a change that creates a branch,
merges, tags, or closes an issue (LAW 41). The project's git flow is a
team decision recorded in the repo; this leaf says how to find it, how to
offer one when there is none, and the rules every flow shares.

## 1. Find the project's flow

In order; the first hit wins:

1. `.dev-rules.json` at the repo root, key `"git_flow"` -- one of the names
   in the table below.
2. The repo's own docs (`CLAUDE.md`, `CONTRIBUTING.md`, `docs/**`) naming a
   branching model, a base branch, or a release procedure.

Found -> follow it, and open its file under `git/` when it names one of the
flows below. A repo exception written in the repo's docs (a path that
ships straight to `main`, no PRs on a private repo) wins over the file.

Branch names, merge commits and tags in the history are evidence to show
the team -- they are not a declaration. A flow inferred from history is
still a flow the team did not choose.

## 2. None declared -> the team picks, before the first branch

Show this table, recommended first, and in the same message ask whether
changes go in by PR or are merged locally once the repo's checks pass.
Wait for the answer. No branch, no commit, no PR until the team picks:
starting on a default "to adjust later" puts the work on a base, a branch
name and a merge style the team may reject.

| Flow (`git_flow`) | Fits when | File |
|---|---|---|
| `release-train` (recommended) | versioned releases; several issues per version; betas before the final | `git/release-train.md` |
| `gitflow` | a release is stabilized while the next one is integrated on `develop` in parallel | `git/gitflow.md` |
| `github-flow` | one version in production, deployed from `main` after every merge | `git/github-flow.md` |
| `gitlab-flow` | deploys promoted through environment branches, or old versions kept on stable branches | `git/gitlab-flow.md` |
| `trunk-based` | many small merges a day, strong CI, unfinished work behind feature flags (LAW 36) | `git/trunk-based.md` |

Record the pick in one commit on `main` (by PR when `main` is protected)
before the first branch is cut from it, so every branch the flow cuts
carries it: `"git_flow": "<name>"` in `.dev-rules.json` (create the file
with just that key when absent) and one line in the repo's `CLAUDE.md`
naming the flow, PR or local merge, and any repo exception. This setup
commit is the one change that lands outside the flow.

## 3. Rules every flow shares

- **Versions are SemVer 2.0.0** (https://semver.org): `MAJOR.MINOR.PATCH`.
  A breaking change bumps MAJOR, a feature MINOR, a fix PATCH -- the
  content decides, never the calendar. A pre-release carries a suffix
  (`-beta.N`, `-rc.N`). No tag yet -> the first version is `v0.1.0`
  (SemVer's initial development); `v1.0.0` is the first release the team
  calls stable.
- **The version is an annotated tag `vX.Y.Z`** (`git tag -a`) on the commit
  that ships. A manifest that carries a version (`package.json`,
  `Cargo.toml`, `pom.xml`, `plugin.json`, ...) agrees with the tag: the
  build writes it from the tag, or a commit on the branch being tagged sets
  it. One source, never hand-edited anywhere else.
- **Commit messages follow Conventional Commits 1.0.0**
  (https://www.conventionalcommits.org): `type(scope): subject`; `!` or a
  `BREAKING CHANGE:` footer marks a breaking change. The types predict the
  SemVer bump. A repo that declares another format keeps its own.
- **Branch name `{type}/issue-N`** when the work has an issue -- `feature`,
  `bug`, `docs`, `chore`, `hotfix`. The number ties branch, issue and
  milestone together; no descriptive suffix.
- **Stage explicit paths.** Never `git add -A` / `git add .` -- they sweep
  in local scratch files, build output and secrets.
- **Conflicts are resolved by hand, reading both sides.** `-X ours` /
  `-X theirs` on a merge keeps one side of every conflicting hunk and
  drops the other without a word -- never use them.
- **Shared history is never rewritten.** No force push and no rebase of a
  branch someone else may have fetched. Whether a change lands in its
  target by merge commit, squash or rebase is the flow's call -- its file
  says.
- **An issue closes with its milestone.** Set the milestone `vX.Y.Z` of the
  version that ships the change, then close. `Closes #N` / `Fixes #N` only
  fire on a merge into the default branch; when the flow merges work
  elsewhere, close by hand.
- **A merged branch is deleted**, on the remote and locally.
