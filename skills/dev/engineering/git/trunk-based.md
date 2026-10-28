# trunk-based -- Trunk-Based Development

A leaf of `../git.md` (read it first: the shared rules apply here too).

Source: https://trunkbaseddevelopment.com

Everyone integrates into one branch, `main` (the trunk), at least daily.

- Short-lived branches (`{type}/issue-N`, hours to two days) from `main`,
  merged by PR once CI is green; a small team may commit straight to
  `main`.
- Unfinished work ships dark behind a feature flag (LAW 36), never waits on
  a long-lived branch.
- `main` is always releasable; CI on every merge is mandatory.
- Release = annotated tag `vX.Y.Z` on `main`. A version that needs
  stabilizing gets `release/vX.Y` cut from `main` just before it ships;
  fixes land on `main` first and are cherry-picked (`git cherry-pick -x`)
  into it. Nobody develops on a release branch.
