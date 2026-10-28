#!/usr/bin/env bash
# dev-rules git-flow guard (on once a project declares its flow).
# Denies a Bash call that lands work on a branch the declared flow protects
# without going through the flow: a merge whose source that branch does not
# take (git merge, git pull <remote> <branch>, gh pr create), or a direct
# git commit on it. The flow is the "git_flow" key of the .dev-rules.json
# COMMITTED at HEAD of the repo the command targets, so the setup commit
# that declares it passes.
#   release-train  main takes release/* and hotfix/* only; no commit on main
#   gitflow        main takes release/* and hotfix/* only; no commit on main
#                  or develop
#   github-flow, gitlab-flow     no commit on main
#   trunk-based, any other name  not gated
# In the same .dev-rules.json:
#   "git_flow_guard": false               -> off for the repo
#   "git_flow_direct_paths": ["site/**"]  -> a commit on a protected branch
#                                            touching only these paths passes
set -euo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
printf '%s' "$input" | jq -e . >/dev/null 2>&1 || exit 0
[ "$(printf '%s' "$input" | jq -r '.tool_name // empty')" = Bash ] || exit 0
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
case "$cmd" in *git*|*gh*) ;; *) exit 0 ;; esac

. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0

dr_shell_words "$cmd"
case " ${DR_WORDS[*]-} " in *" commit "*|*" merge "*|*" pull "*|*" pr "*) ;; *) exit 0 ;; esac

base="$(printf '%s' "$input" | jq -r '.cwd // empty')"
dir="$(dr_words_cwd "${base:-${CLAUDE_PROJECT_DIR:-.}}")"
cfg="$(git -C "$dir" show HEAD:.dev-rules.json 2>/dev/null)" || exit 0
fl="$(printf '%s' "$cfg" | jq -r '.git_flow // empty' 2>/dev/null)" || exit 0
case "$fl" in release-train|gitflow|github-flow|gitlab-flow) ;; *) exit 0 ;; esac
[ "$(printf '%s' "$cfg" | jq -r '.git_flow_guard' 2>/dev/null)" != false ] || exit 0
cur="$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null || true)"

deny() {
  jq -nc --arg r "dev-rules git-flow guard: this repo's flow is $fl (\"git_flow\" in .dev-rules.json). $1 See the dev skill, engineering/git/$fl.md. Do NOT get around it on your own -- if the work must land this way, ASK THE USER: the team may list paths that ship straight to a protected branch in \"git_flow_direct_paths\", turn this guard off with \"git_flow_guard\": false, or disable all dev-rules gates (touch .dev-rules/.off, or DEV_RULES_OFF=1)." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# short <ref> -> the branch name, without refs/heads/, refs/remotes/ or a remote.
short() {
  local r="${1#refs/heads/}" rem
  r="${r#refs/remotes/}"
  for rem in $(git -C "$dir" remote 2>/dev/null); do
    case "$r" in "$rem"/*) r="${r#"$rem"/}"; break ;; esac
  done
  printf '%s' "$r"
}

# check_merge <target> <source> -- denies a source the target branch does not take.
check_merge() {
  local s; s="$(short "$2")"
  [ -n "$1" ] && [ -n "$s" ] && [ "$s" != "$1" ] || return 0
  case "$fl:$1" in
    release-train:main|gitflow:main)
      case "$s" in release/*|hotfix/*) return 0 ;; esac
      local into="the active release/vX.Y.Z (the highest one with no vX.Y.Z tag)"
      [ "$fl" = gitflow ] && into="develop"
      deny "\`$1\` takes merges only from release/* and hotfix/*, not \`$s\`. Merge \`$s\` into $into instead." ;;
  esac
}

# direct_ok <path>... -- every path matches a "git_flow_direct_paths" glob.
direct_ok() {
  local p g hit globs
  globs="$(printf '%s' "$cfg" | jq -r '.git_flow_direct_paths[]?' 2>/dev/null || true)"
  [ -n "$globs" ] && [ "$#" -gt 0 ] || return 1
  for p in "$@"; do
    hit=1
    while IFS= read -r g; do
      [ -n "$g" ] && dr_glob_match "${p#./}" "$g" && { hit=0; break; }
    done <<EOF
$globs
EOF
    [ "$hit" = 0 ] || return 1
  done
}

added=(); add_unknown=0

# check_commit <commit args>... -- denies a direct commit on a protected branch.
check_commit() {
  case "$fl:$cur" in *:main|gitflow:develop) ;; *) return 0 ;; esac
  git -C "$dir" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 && return 0
  local a all=0 val=0 pre p specs=() set=()
  for a in "$@"; do
    if [ "$val" = 1 ]; then val=0; continue; fi
    case "$a" in
      --all) all=1 ;;
      --message|--file|--reuse-message|--reedit-message|--template|--author|--date|--cleanup|--fixup|--squash|--trailer) val=1 ;;
      --*) ;;
      -*) case "$a" in *a*) all=1 ;; esac
          case "$a" in *[mFCct]) val=1 ;; esac ;;
      *) specs[${#specs[@]}]="$a" ;;
    esac
  done
  pre="$(git -C "$dir" rev-parse --show-prefix 2>/dev/null || true)"
  if [ "${#specs[@]}" -gt 0 ]; then
    for p in "${specs[@]}"; do set[${#set[@]}]="$pre${p#./}"; done
  elif [ "$add_unknown" = 0 ]; then
    for p in ${added[@]+"${added[@]}"}; do set[${#set[@]}]="$pre$p"; done
    while IFS= read -r p; do [ -z "$p" ] || set[${#set[@]}]="$p"; done <<EOF
$(git -C "$dir" diff --cached --name-only 2>/dev/null; [ "$all" = 0 ] || git -C "$dir" diff --name-only 2>/dev/null)
EOF
  fi
  # git add -A / . / -u before the commit: what it commits is unknown.
  if [ "$add_unknown" = 0 ] || [ "${#specs[@]}" -gt 0 ]; then
    direct_ok ${set[@]+"${set[@]}"} && return 0
  fi
  case "$fl" in
    release-train) a="Commit on an issue branch ({type}/issue-N) cut from the active release, and merge it there." ;;
    gitflow) a="Commit on a feature/* branch cut from develop, or on the release/* or hotfix/* branch the change belongs to." ;;
    *) a="Commit on a branch cut from main and merge it back (by PR when the repo uses PRs)." ;;
  esac
  deny "A commit straight on \`$cur\` skips the flow. $a"
}

# switch_to <switch|checkout> <args>... -- follows the branch a command moves to.
switch_to() {
  local sub="$1" a take=0; shift
  for a in "$@"; do
    if [ "$take" = 1 ]; then cur="$a"; return; fi
    case "$a" in
      -c|-C|-b|-B|--create|--force-create|--orphan) take=1 ;;
      -d|--detach|-) cur=""; return ;;
      --) return ;;
      -*) ;;
      *)
        if [ "$sub" = switch ] || git -C "$dir" show-ref -q --verify "refs/heads/$a" ||
          [ -n "$(git -C "$dir" for-each-ref --count=1 "refs/remotes/*/$a" 2>/dev/null)" ]; then
          cur="$a"
        elif git -C "$dir" rev-parse -q --verify "$a^{commit}" >/dev/null 2>&1; then
          cur=""
        fi
        return ;;
    esac
  done
}

# run_seg -- checks one simple command (the words in seg).
run_seg() {
  local n=${#seg[@]} i=0 a val=0 pos=0 dd=0 take="" b="" h
  while [ "$i" -lt "$n" ]; do case "${seg[$i]}" in *=*) i=$((i+1)) ;; *) break ;; esac; done
  [ "$i" -lt "$n" ] || return 0
  if [ "${seg[$i]}" = gh ]; then
    [ "${seg[$((i+1))]:-}" = pr ] && [ "${seg[$((i+2))]:-}" = create ] || return 0
    h="$cur"
    for a in "${seg[@]:i+3}"; do
      case "$take" in B) b="$a"; take=""; continue ;; H) h="$a"; take=""; continue ;; esac
      case "$a" in
        -B|--base) take=B ;;
        --base=*) b="${a#--base=}" ;;
        -H|--head) take=H ;;
        --head=*) h="${a#--head=}" ;;
      esac
    done
    [ -n "$b" ] || b="$(short "$(git -C "$dir" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)")"
    check_merge "$b" "${h##*:}"
    return 0
  fi
  [ "${seg[$i]}" = git ] || return 0
  i=$((i+1))
  while [ "$i" -lt "$n" ]; do
    case "${seg[$i]}" in
      -C|-c|--git-dir|--work-tree|--namespace) i=$((i+2)) ;;
      -*) i=$((i+1)) ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "$n" ] || return 0
  local sub="${seg[$i]}" args=("${seg[@]:i+1}")
  case "$sub" in
    switch|checkout) switch_to "$sub" ${args[@]+"${args[@]}"} ;;
    commit) check_commit ${args[@]+"${args[@]}"} ;;
    merge)
      for a in ${args[@]+"${args[@]}"}; do
        if [ "$val" = 1 ]; then val=0; continue; fi
        case "$a" in
          --abort|--continue|--quit|--skip) return 0 ;;
          -m|-F|-s|-X|--strategy|--strategy-option|--file|--into-name) val=1 ;;
          -*) ;;
          *) check_merge "$cur" "$a" ;;
        esac
      done ;;
    pull)
      for a in ${args[@]+"${args[@]}"}; do
        if [ "$val" = 1 ]; then val=0; continue; fi
        case "$a" in
          -s|-X|--strategy|--strategy-option|--depth|--deepen|--shallow-since|--shallow-exclude|-j|--jobs|--upload-pack|-o|--server-option) val=1 ;;
          -*) ;;
          *) pos=$((pos+1)); [ "$pos" = 1 ] || { a="${a#+}"; check_merge "$cur" "${a%%:*}"; } ;;
        esac
      done ;;
    add)
      for a in ${args[@]+"${args[@]}"}; do
        if [ "$dd" = 0 ]; then
          case "$a" in
            --) dd=1; continue ;;
            -A|--all|-u|--update|--no-ignore-removal) add_unknown=1; continue ;;
            -*) continue ;;
          esac
        fi
        case "$a" in .|./|:/*|*\**) add_unknown=1 ;; *) added[${#added[@]}]="${a#./}" ;; esac
      done ;;
  esac
}

# Walk the command one simple command at a time; a redirection's fd number
# and target are not arguments.
seg=(); skip=0
for w in ${DR_WORDS[@]+"${DR_WORDS[@]}"}; do
  if [ "$skip" = 1 ]; then skip=0; continue; fi
  case "$w" in
    '<'*|'>'*|'&>'*)
      n=${#seg[@]}
      if [ "$n" -gt 0 ]; then case "${seg[$((n-1))]}" in *[!0-9]*) ;; *) unset "seg[$((n-1))]" ;; esac; fi
      skip=1 ;;
    ';'*|'&'*|'|'*|'('|')') [ "${#seg[@]}" = 0 ] || run_seg; seg=() ;;
    *) seg[${#seg[@]}]="$w" ;;
  esac
done
[ "${#seg[@]}" = 0 ] || run_seg
exit 0
