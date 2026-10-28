# gitflow -- Git Flow (Vincent Driessen, 2010)

A leaf of `../git.md` (read it first: the shared rules apply here too).

Source: https://nvie.com/posts/a-successful-git-branching-model/ -- the
author's 2020 note on that page points teams doing continuous delivery to
a simpler flow (`github-flow`).

| Branch | Cut from | Merges into |
|---|---|---|
| `main` | -- | nothing; every merge on it is a release, tagged `vX.Y.Z` |
| `develop` | `main`, once | nothing; the integration branch of the next release |
| `feature/`, `bug/`, `docs/`, `chore/` + `issue-N` | `develop` | `develop` |
| `release/vX.Y.Z` | `develop`, when it holds what the version ships | `main` (+ tag) and `develop` |
| `hotfix/issue-N` | `main` | `main` (+ tag) and `develop` -- or the open release branch instead of `develop` |

- Work lands on `develop`, never on a release branch. A release branch
  takes only fixes, docs and the version bump while it is stabilized.
- Every merge is `--no-ff`, so each branch's commits stay grouped.
- The version bump is a commit on the release or hotfix branch, before it
  merges into `main`.
- A hotfix while a release branch is open merges into that release instead
  of `develop`; it reaches `develop` when the release does.
- `Closes #N` fires on a merge into `develop` only when `develop` is the
  repo's default branch; otherwise close by hand.
