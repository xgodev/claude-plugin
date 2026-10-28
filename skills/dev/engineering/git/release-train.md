# release-train -- the recommended flow

A leaf of `../git.md` (read it first: the shared rules apply here too).

Every change boards the active release branch; that branch merged into
`main` and tagged is the shipped version. Two kinds of long-lived branch:
`main` and the one active `release/vX.Y.Z`.

```
{type}/issue-N --merge--> release/vX.Y.Z --merge + tag vX.Y.Z--> main
hotfix/issue-N --merge + tag vX.Y.Z--> main --merge--> active release
```

| Branch | Holds | Cut from | Merges into |
|---|---|---|---|
| `main` | exactly what shipped; every merge on it is tagged | -- | the active release, after a hotfix |
| `release/vX.Y.Z` | the version's cycle; `vX.Y.Z-beta.N` tags on it are pre-releases | `main` | `main` |
| `feature/`, `bug/`, `docs/`, `chore/` + `issue-N` | one issue | the active release | the active release |
| `hotfix/issue-N` | an urgent fix to what shipped | `main` | `main`, then the active release |

Every merge below goes by PR when the repo uses PRs, otherwise locally
once the repo's checks pass -- always a merge commit (`--no-ff`).

## The active release

The active release is the HIGHEST `release/vX.Y.Z` with no `vX.Y.Z` tag.
An old release branch left on the remote is not active: its tag says the
version is out, and anything merged into it never ships.

```bash
git fetch --tags origin
git branch -r --list 'origin/release/*'
git tag -l 'v1.4.1'            # empty = not shipped yet
```

One release in flight at a time. None active -> cut one from `main`,
versioned by what it will carry, counted from the last tag on `main`: a
bug opens the next PATCH, a feature the next MINOR, a breaking change the
next MAJOR.

```bash
git switch -c release/v1.4.1 origin/main && git push -u origin release/v1.4.1
```

A bigger change boarding a smaller cycle (a feature into a PATCH cycle)
renames the cycle the same day -- branch and milestone to the bigger
version, open PRs retargeted, old branch name deleted. Never open a second
release branch next to an untagged one.

## Working an issue

1. Cut from the up-to-date active release:
   `git fetch origin && git switch -c bug/issue-87 origin/release/v1.4.1 && git push -u origin bug/issue-87`
2. Before working, and again before merging back, bring the release in:
   `git fetch origin && git merge origin/release/v1.4.1` -- conflicts by
   hand.
3. Merge into the active release:
   `git switch release/v1.4.1 && git pull && git merge --no-ff bug/issue-87 && git push`
4. Milestone `v1.4.1`, close the issue, delete the branch.

Always `git merge`, never rebase or squash: the release keeps every
issue's commits, `main` keeps every release's.

## Shipping

- **Beta:** annotated tag `vX.Y.Z-beta.N` on the release branch tip. Nothing
  merges into `main`.
- **Final:** bump any versioned manifest on the release branch, then
  `git switch main && git pull && git merge --no-ff release/vX.Y.Z`, annotated
  tag `vX.Y.Z` on that merge commit, push the branch and the tag. The next
  cycle is cut from `main` after the tag.
- **Hotfix:** when the active release can ship now (a PATCH cycle with
  nothing unfinished), fix it there and ship it -- no hotfix branch. When it
  cannot, cut `hotfix/issue-N` from `main`; it ships as the next PATCH
  after `main`'s last tag (merge into `main` + tag), then `main` is merged
  into the active release so the fix is not lost. If the active release
  had that same version, rename it to the next one.

## Adopting it in a repo that has `develop`

When `develop` holds work `main` does not, the first cycle is cut from
`develop` instead of `main`; otherwise from `main`. Open issue branches
retarget to the active release. Once that release ships, the team deletes
`develop` and the tagged release branches left on the remote.

## Why there is no `develop`

Every change enters through the active release, so a `develop` would only
receive `main` back after each release: a copy of `main` that every step
must keep in sync, and that docs drift about (one says work lands there,
another that it lands on the release). The next cycle is cut from `main`.
A team that wants an integration branch ahead of the release picks
`gitflow`.
