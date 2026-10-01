#!/usr/bin/env bash
# Responsibility: report checkouts holding work that exists nowhere but this machine.
set -uo pipefail

# Work that is not on the remote is work nobody can pull and nothing can
# restore. Agent workspaces are covered by their own check. HYGIENE_OWNERS is
# a space-separated list of substrings a remote URL must contain -- without it
# every vendored third-party clone under the roots is reported too.
owners="${HYGIENE_OWNERS:-}"
# A tree that has been dirty since 2022 is abandoned junk, not work in danger;
# only a checkout touched recently is worth a daily nudge. Commits that exist
# nowhere but here are reported whatever their age.
recent_days="${HYGIENE_RECENT_DAYS:-14}"
cutoff=$(( $(date +%s) - recent_days * 86400 ))
shopt -s nullglob
for root in ${HYGIENE_ROOTS//:/ }; do
  while IFS= read -r gitdir; do
    repo="$(dirname "$gitdir")"
    case "$repo" in */.solvers/*|*/node_modules/*) continue ;; esac
    if [ -n "$owners" ]; then
      remote="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
      match=0
      for owner in $owners; do
        case "$remote" in *"$owner"*) match=1 ;; esac
      done
      [ "$match" = "1" ] || continue
    fi
    label="${repo#$root/}"
    dirty="$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    ahead="$(git -C "$repo" log --oneline "@{upstream}..HEAD" 2>/dev/null | wc -l | tr -d ' ')"
    [ "$dirty" = "0" ] && [ "$ahead" = "0" ] && continue
    if [ "$ahead" = "0" ]; then
      last="$(git -C "$repo" log -1 --format=%ct 2>/dev/null || echo 0)"
      [ "$last" -ge "$cutoff" ] || continue
    fi
    detail=""
    [ "$dirty" != "0" ] && detail="$dirty uncommitted file(s)"
    [ "$ahead" != "0" ] && detail="${detail:+$detail, }$ahead commit(s) not pushed"
    finding "$label: $detail"
  done < <(find "$root" -maxdepth 4 -type d -name .git 2>/dev/null)
done
