#!/usr/bin/env bash
# SessionStart (dev-rules): put LAW 42 in every session that opens inside a
# git repo, before any issue work starts -- the rule has to be in context the
# moment an unrelated fix turns up, not only once the dev skill is loaded
# (issue #41). Fires on every source (startup/resume/clear/compact), so a
# compacted session gets it back.
# Context only -- this hook never blocks anything.
set -euo pipefail

cat >/dev/null 2>&1 || true   # the event payload is not needed
command -v jq >/dev/null 2>&1 || exit 0

. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0

git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

jq -n '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:"dev-rules LAW 42 -- work outside the current issue. When a fix or subject that the current issue does not need turns up (a bug seen in passing, a cleanup, a problem in another area), none of it goes on the current issue branch (not even as its own commit) and nothing is created yet: propose it to the user in one line that names both -- a new issue plus a separate session for it. A rule against creating issues unasked forbids the creating, not the proposal. Only after their yes: search open AND closed issues for one that already covers it (GitHub: `gh issue list --state all --search \"<terms>\"`), create the issue only if none does, then start the separate session with a self-contained brief (issue link, scope, done criteria), titled `TYPE - #N title` (FEAT, FIX, DOCS, CHORE, ...). No session tool in this harness -> give the user the brief and the title to open it. Full rule: the dev skill, engineering/rules/flow.md."}}'
