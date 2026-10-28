# gitlab-flow -- GitLab Flow

A leaf of `../git.md` (read it first: the shared rules apply here too).

GitLab's model (2014): GitHub Flow plus downstream branches for deploys or
for maintained versions. `main` is upstream; changes only flow downstream.

**Work:** `{type}/issue-N` from `main`, merge request into `main` (merge
commit or squash -- the repo keeps one choice).

The repo uses ONE of the two downstream variants -- it names which:

- **Environment branches** (deploys behind a gate): `main` ->
  `pre-production` -> `production`. Deploying = merging `main` into the
  next environment branch. Nobody commits on an environment branch.
- **Release branches** (several versions supported): `X-Y-stable` cut from
  `main` when a version ships; its `vX.Y.Z` tags live on it. A fix lands on
  `main` first, then is cherry-picked (`git cherry-pick -x`) into each
  stable branch that needs it.

**Upstream first:** a fix never lands only downstream -- the next promotion
from `main` would bring the bug back.
