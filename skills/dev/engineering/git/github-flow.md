# github-flow -- GitHub Flow

A leaf of `../git.md` (read it first: the shared rules apply here too).

Source: https://docs.github.com/en/get-started/using-github/github-flow

One long-lived branch, `main`, always deployable.

1. Branch from `main`: `{type}/issue-N`.
2. Commit, push, open a PR to `main` early; CI and review run on it.
3. Merge when green and approved -- the repo picks merge commit or squash
   and keeps that one choice -- then delete the branch.
4. Deploy from `main` right after the merge.
5. Release = annotated tag `vX.Y.Z` on a `main` commit; the bump comes from
   the commits since the last tag (their Conventional Commits types).

- No `develop`, no `release/*`: an urgent fix is one more branch from
  `main`, merged first.
- Unfinished work merged into `main` stays off behind a feature flag
  (LAW 36).
- PRs target the default branch, so `Closes #N` fires on merge.
