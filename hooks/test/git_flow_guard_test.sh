#!/usr/bin/env bash
# Feeds hook-input JSON to git-flow-guard.sh against throwaway git repos and
# asserts deny/allow. The flow is the "git_flow" committed at the target
# repo's HEAD, so the commit that declares it is never blocked.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$HERE/../dev-rules/git-flow-guard.sh"
SBX="$(mktemp -d)"
trap 'rm -rf "$SBX"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset DEV_RULES_OFF
fail=0
denied() { grep -q '"permissionDecision":"deny"' <<<"$1"; }
# run <cwd> <command> -> the guard's output for a Bash call run from <cwd>.
run() {
  jq -nc --arg c "$2" --arg d "$1" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' |
    CLAUDE_PROJECT_DIR="$1" bash "$GUARD"
}
expect() { # <deny|allow> <label> <cwd> <command>
  local out; out="$(run "$3" "$4")"
  if [ "$1" = deny ]; then
    if denied "$out"; then echo "ok  : $2"; else echo "FAIL: $2 (expected deny)"; fail=1; fi
  else
    if denied "$out"; then echo "FAIL: $2 (expected allow): $out"; fail=1; else echo "ok  : $2"; fi
  fi
}
# repo <dir> <dev-rules.json or empty> -> main with the config committed, plus
# release/v1.4.1, feature/issue-3, hotfix/issue-9 and develop; HEAD on main.
repo() {
  git init -q -b main "$1"
  [ -z "$2" ] || printf '%s' "$2" >"$1/.dev-rules.json"
  echo a >"$1/a.txt"
  git -C "$1" add -A && git -C "$1" commit -qm init
  local b
  for b in release/v1.4.1 feature/issue-3 hotfix/issue-9 develop; do git -C "$1" branch "$b"; done
  git -C "$1" remote add origin https://example.invalid/r.git
  git -C "$1" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
}

# 1. No flow declared -> nothing is gated.
R="$SBX/none"; repo "$R" ''
expect allow "no git_flow: merge of an issue branch into main" "$R" "git merge feature/issue-3"
expect allow "no git_flow: commit on main" "$R" "git commit -m x"

# 2. The setup commit declares the flow in the working tree, not yet at HEAD.
printf '%s' '{"git_flow": "release-train"}' >"$R/.dev-rules.json"
expect allow "setup commit (flow not committed yet) passes" "$R" "git add .dev-rules.json && git commit -m setup"

# 3. release-train: main takes only release/* and hotfix/*, never a direct commit.
R="$SBX/rt"; repo "$R" '{"git_flow": "release-train"}'
out="$(run "$R" "git merge --no-ff feature/issue-3")"
if denied "$out"; then echo "ok  : release-train: issue branch -> main denied"; else echo "FAIL: release-train: issue branch -> main must be denied"; fail=1; fi
if grep -q 'release-train' <<<"$out" && grep -q 'feature/issue-3' <<<"$out" && grep -qi 'ask the user' <<<"$out" && grep -q 'git_flow_guard' <<<"$out"; then
  echo "ok  : deny names the flow and the branch, asks the user, offers the opt-out"
else
  echo "FAIL: deny must name the flow and branch, ASK THE USER, and mention git_flow_guard: $out"; fail=1
fi
expect allow "release-train: release -> main" "$R" "git merge --no-ff release/v1.4.1"
expect allow "release-train: origin/release -> main" "$R" "git merge --no-ff origin/release/v1.4.1"
expect allow "release-train: hotfix -> main" "$R" "git merge --no-ff -m 'ship' hotfix/issue-9"
expect allow "release-train: main syncs with its own remote" "$R" "git merge origin/main"
expect allow "release-train: plain pull on main" "$R" "git pull"
expect deny "release-train: pull of an issue branch into main" "$R" "git pull origin feature/issue-3"
expect allow "release-train: merge --abort" "$R" "git merge --abort"
expect deny "release-train: develop -> main" "$R" "git merge develop"
expect deny "release-train: direct commit on main" "$R" "git commit -m x"
expect deny "release-train: amend on main" "$R" "git commit --amend --no-edit"
git -C "$R" rev-parse HEAD >"$R/.git/MERGE_HEAD"
expect allow "release-train: commit that concludes a merge on main" "$R" "git commit --no-edit"
rm -f "$R/.git/MERGE_HEAD"
expect allow "read-only git on main" "$R" "git status && git log --oneline -3"
expect allow "a quoted string is not a command" "$R" "echo 'git merge feature/issue-3'"

# 4. The branch the command targets: switches earlier in the same command,
# git -C and cd count.
git -C "$R" switch -q feature/issue-3
expect allow "release-train: commit on the issue branch" "$R" "git commit -m x"
expect deny "switch main && merge issue branch" "$R" "git switch main && git merge feature/issue-3"
expect deny "checkout main; merge issue branch" "$R" "git checkout main; git merge feature/issue-3"
expect allow "switch to the release && merge issue branch" "$R" "git switch release/v1.4.1 && git merge --no-ff feature/issue-3"
expect allow "switch -c a new branch && commit" "$R" "git switch -c bug/issue-7 origin/main && git commit -m x"
git -C "$R" switch -q main
expect deny "git -C <repo> merge into main" "$SBX" "git -C $R merge feature/issue-3"
expect deny "cd <repo> && merge into main" "$SBX" "cd $R && git merge feature/issue-3"

# 5. A PR is a merge too: its base is the target, its head the source.
git -C "$R" switch -q feature/issue-3
expect deny "gh pr create --base main from an issue branch" "$R" "gh pr create --base main --title x --body y"
expect deny "gh pr create with no base (default branch main)" "$R" "gh pr create --fill"
expect allow "gh pr create --base release" "$R" "gh pr create -B release/v1.4.1 --fill"
expect allow "gh pr create --head release --base main" "$R" "gh pr create --head release/v1.4.1 --base=main --fill"
git -C "$R" switch -q main

# 6. gitflow: develop integrates features, main takes only release/hotfix.
R="$SBX/gf"; repo "$R" '{"git_flow": "gitflow"}'
git -C "$R" switch -q develop
expect allow "gitflow: feature -> develop" "$R" "git merge --no-ff feature/issue-3"
expect deny "gitflow: direct commit on develop" "$R" "git commit -m x"
git -C "$R" switch -q main
expect deny "gitflow: develop -> main" "$R" "git merge develop"
expect allow "gitflow: release -> main" "$R" "git merge --no-ff release/v1.4.1"

# 7. github-flow / gitlab-flow: any branch merges into main, no direct commit.
for f in github-flow gitlab-flow; do
  R="$SBX/$f"; repo "$R" "{\"git_flow\": \"$f\"}"
  expect allow "$f: issue branch -> main" "$R" "git merge --no-ff feature/issue-3"
  expect deny "$f: direct commit on main" "$R" "git commit -m x"
done

# 8. trunk-based: committing on the trunk IS the flow.
R="$SBX/tb"; repo "$R" '{"git_flow": "trunk-based"}'
expect allow "trunk-based: commit on main" "$R" "git commit -m x"

# 9. Unknown flow names and the opt-outs leave everything allowed.
R="$SBX/unk"; repo "$R" '{"git_flow": "our-own"}'
expect allow "unknown flow name: not gated" "$R" "git commit -m x"
R="$SBX/off"; repo "$R" '{"git_flow": "release-train", "git_flow_guard": false}'
expect allow "git_flow_guard false: not gated" "$R" "git merge feature/issue-3"
R="$SBX/rt"
out="$(jq -nc --arg c "git commit -m x" --arg d "$R" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | DEV_RULES_OFF=1 CLAUDE_PROJECT_DIR="$R" bash "$GUARD")"
if denied "$out"; then echo "FAIL: DEV_RULES_OFF=1 must disable the guard"; fail=1; else echo "ok  : DEV_RULES_OFF=1 disables the guard"; fi

# 10. A repo exception: paths that ship straight to main.
R="$SBX/ex"; repo "$R" '{"git_flow": "release-train", "git_flow_direct_paths": ["site/**"]}'
mkdir -p "$R/site" "$R/src"; echo s >"$R/site/index.html"; echo s >"$R/src/a.rs"
expect allow "exception: commit of site/ only on main" "$R" "git add site/index.html && git commit -m site"
expect deny "exception: commit with a path outside site/" "$R" "git add site/index.html src/a.rs && git commit -m x"
expect deny "exception: git add -A hides what is committed" "$R" "git add -A && git commit -m x"
git -C "$R" add src/a.rs
expect deny "exception: a staged path outside site/" "$R" "git add site/index.html && git commit -m x"
git -C "$R" reset -q src/a.rs
git -C "$R" add site/index.html
expect allow "exception: already-staged site/ only" "$R" "git commit -m site"
expect deny "exception: merging an issue branch is still denied" "$R" "git merge feature/issue-3"

# 11. Non-Bash tools are never gated.
out="$(jq -nc --arg d "$R" '{tool_name:"Edit",tool_input:{file_path:"x"},cwd:$d}' | CLAUDE_PROJECT_DIR="$R" bash "$GUARD")"
if denied "$out"; then echo "FAIL: Edit must not be gated"; fail=1; else echo "ok  : Edit not gated"; fi

exit $fail
