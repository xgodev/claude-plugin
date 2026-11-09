#!/usr/bin/env bash
# antigravity-adapter.sh -- Dual-target adapter for Google Antigravity.
# Reads canonical hooks from hooks/hooks.json, maps Antigravity event payloads
# (stdin protojson) to Claude Code tool calls, executes canonical hooks, and
# translates outputs back to Antigravity contracts.
set -u

EVENT="${1:-PreToolUse}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL_HOOKS="$PLUGIN_ROOT/hooks/hooks.json"

# Fail open if jq is missing
if ! command -v jq >/dev/null 2>&1; then
  case "$EVENT" in
    PreToolUse) printf '{"decision":"allow"}\n' ;;
    *) printf '{}\n' ;;
  esac
  exit 0
fi

input="$(cat)"
# Fail open if input is not valid JSON
if ! printf '%s' "$input" | jq -e . >/dev/null 2>&1; then
  case "$EVENT" in
    PreToolUse) printf '{"decision":"allow"}\n' ;;
    *) printf '{}\n' ;;
  esac
  exit 0
fi

# Locate project and export canonical environment variables
proj="$(printf '%s' "$input" | jq -r '.workspacePaths[0] // empty')"
proj="${proj:-${CLAUDE_PROJECT_DIR:-$PWD}}"
proj="${proj%/}"
export CLAUDE_PROJECT_DIR="$proj"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Source detection library for workspace and path resolution
if [ -f "$PLUGIN_ROOT/hooks/dev-rules/lib/detect.sh" ]; then
  # shellcheck source=/dev/null
  . "$PLUGIN_ROOT/hooks/dev-rules/lib/detect.sh"
fi

case "$EVENT" in
  PreToolUse)
    raw_tool="$(printf '%s' "$input" | jq -r '.toolCall.name // empty')"
    claude_tool=""
    file_path=""
    cmd=""
    old_str=""
    new_str=""
    grep_path=""
    grep_pat=""

    case "$raw_tool" in
      run_command)
        claude_tool="Bash"
        cmd="$(printf '%s' "$input" | jq -r '.toolCall.args.CommandLine // empty')"
        ;;
      read_file|view_file)
        claude_tool="Read"
        file_path="$(printf '%s' "$input" | jq -r '.toolCall.args.Path // .toolCall.args.AbsolutePath // empty')"
        ;;
      write_file)
        claude_tool="Write"
        file_path="$(printf '%s' "$input" | jq -r '.toolCall.args.Path // .toolCall.args.TargetFile // empty')"
        new_str="$(printf '%s' "$input" | jq -r '.toolCall.args.Content // .toolCall.args.CodeContent // ""')"
        ;;
      edit_file|replace_file_content)
        claude_tool="Edit"
        file_path="$(printf '%s' "$input" | jq -r '.toolCall.args.Path // .toolCall.args.TargetFile // empty')"
        old_str="$(printf '%s' "$input" | jq -r '.toolCall.args.Target // .toolCall.args.OldCode // ""')"
        new_str="$(printf '%s' "$input" | jq -r '.toolCall.args.Replacement // .toolCall.args.NewCode // ""')"
        ;;
      multi_replace_file_content)
        claude_tool="Edit"
        file_path="$(printf '%s' "$input" | jq -r '.toolCall.args.TargetFile // .toolCall.args.Path // empty')"
        old_str="$(printf '%s' "$input" | jq -r '[.toolCall.args.ReplacementChunks[]?.Target // ""] | join("\n")')"
        new_str="$(printf '%s' "$input" | jq -r '[.toolCall.args.ReplacementChunks[]?.Replacement // ""] | join("\n")')"
        ;;
      grep_search)
        claude_tool="Grep"
        grep_path="$(printf '%s' "$input" | jq -r '.toolCall.args.SearchPath // .toolCall.args.SearchDirectory // empty')"
        grep_pat="$(printf '%s' "$input" | jq -r '.toolCall.args.Pattern // empty')"
        ;;
      find_by_name)
        claude_tool="Glob"
        grep_path="$(printf '%s' "$input" | jq -r '.toolCall.args.SearchDirectory // .toolCall.args.Path // empty')"
        grep_pat="$(printf '%s' "$input" | jq -r '.toolCall.args.Pattern // empty')"
        ;;
      *)
        printf '{"decision":"allow"}\n'
        exit 0
        ;;
    esac

    # Build Claude Code synthetic tool input
    claude_input="$(jq -nc \
      --arg tn "$claude_tool" \
      --arg cwd "$proj" \
      --arg fp "$file_path" \
      --arg c "$cmd" \
      --arg os "$old_str" \
      --arg ns "$new_str" \
      --arg gp "$grep_path" \
      --arg gpat "$grep_pat" \
      '{
        tool_name: $tn,
        cwd: $cwd,
        tool_input: (
          if $tn == "Bash" then {command: $c}
          elif $tn == "Read" then {file_path: $fp}
          elif $tn == "Write" then {file_path: $fp, content: $ns}
          elif $tn == "Edit" then {file_path: $fp, old_string: $os, new_string: $ns}
          elif $tn == "Grep" or $tn == "Glob" then {path: $gp, glob: $gpat}
          else {} end
        )
      }')"

    # Evaluate all matching PreToolUse hooks defined in hooks/hooks.json
    hook_count="$(jq -r '.hooks.PreToolUse | length' "$CANONICAL_HOOKS" 2>/dev/null || echo 0)"
    idx=0
    while [ "$idx" -lt "$hook_count" ]; do
      matcher="$(jq -r ".hooks.PreToolUse[$idx].matcher // empty" "$CANONICAL_HOOKS")"
      if [ -n "$matcher" ] && printf '%s' "$claude_tool" | grep -qE "^($matcher)$"; then
        cmd_count="$(jq -r ".hooks.PreToolUse[$idx].hooks | length" "$CANONICAL_HOOKS" 2>/dev/null || echo 0)"
        cidx=0
        while [ "$cidx" -lt "$cmd_count" ]; do
          raw_cmd="$(jq -r ".hooks.PreToolUse[$idx].hooks[$cidx].command // empty" "$CANONICAL_HOOKS")"
          if [ -n "$raw_cmd" ]; then
            hook_out="$(printf '%s' "$claude_input" | eval "$raw_cmd" 2>/dev/null || true)"
            if printf '%s' "$hook_out" | jq -e '(.hookSpecificOutput.permissionDecision == "deny") or (.permissionDecision == "deny")' >/dev/null 2>&1; then
              reason="$(printf '%s' "$hook_out" | jq -r '.hookSpecificOutput.permissionDecisionReason // .permissionDecisionReason // "Execution denied by dev-rules"' 2>/dev/null)"
              jq -nc --arg r "$reason" '{"decision": "deny", "reason": $r}'
              exit 0
            fi
          fi
          cidx=$((cidx + 1))
        done
      fi
      idx=$((idx + 1))
    done

    printf '{"decision":"allow"}\n'
    exit 0
    ;;

  PostToolUse)
    raw_tool="$(printf '%s' "$input" | jq -r '.toolCall.name // empty')"
    [ "$raw_tool" = "run_command" ] || { printf '{}\n'; exit 0; }

    cmd="$(printf '%s' "$input" | jq -r '.toolCall.args.CommandLine // empty')"
    err="$(printf '%s' "$input" | jq -r '.error // empty')"
    if [ -n "$err" ]; then
      exit_code=1
    else
      exit_code=0
    fi

    claude_input="$(jq -nc \
      --arg cwd "$proj" \
      --arg c "$cmd" \
      --argjson ec "$exit_code" \
      '{
        tool_name: "Bash",
        cwd: $cwd,
        tool_input: {command: $c},
        tool_response: {exit_code: $ec}
      }')"

    # Evaluate all matching PostToolUse hooks
    hook_count="$(jq -r '.hooks.PostToolUse | length' "$CANONICAL_HOOKS" 2>/dev/null || echo 0)"
    idx=0
    pending_notices=()

    while [ "$idx" -lt "$hook_count" ]; do
      matcher="$(jq -r ".hooks.PostToolUse[$idx].matcher // empty" "$CANONICAL_HOOKS")"
      if [ -z "$matcher" ] || printf 'Bash' | grep -qE "^($matcher)$"; then
        cmd_count="$(jq -r ".hooks.PostToolUse[$idx].hooks | length" "$CANONICAL_HOOKS" 2>/dev/null || echo 0)"
        cidx=0
        while [ "$cidx" -lt "$cmd_count" ]; do
          raw_cmd="$(jq -r ".hooks.PostToolUse[$idx].hooks[$cidx].command // empty" "$CANONICAL_HOOKS")"
          if [ -n "$raw_cmd" ]; then
            hook_out="$(printf '%s' "$claude_input" | eval "$raw_cmd" 2>/dev/null || true)"
            ctx="$(printf '%s' "$hook_out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
            if [ -n "$ctx" ]; then
              pending_notices+=("$ctx")
            fi
          fi
          cidx=$((cidx + 1))
        done
      fi
      idx=$((idx + 1))
    done

    # Buffer pending notices for PostInvocation in the active workspace
    if [ "${#pending_notices[@]}" -gt 0 ]; then
      ws=""
      if command -v dr_workspace >/dev/null 2>&1 && command -v dr_bash_cwd >/dev/null 2>&1; then
        ws="$(dr_workspace "$(dr_bash_cwd "$cmd" "$proj")")"
      else
        ws="$proj"
      fi
      mkdir -p "$ws/.dev-rules"
      notice_file="$ws/.dev-rules/.agy-pending-notices"
      for n in "${pending_notices[@]}"; do
        printf '%s\n' "$n" >> "$notice_file"
      done
    fi

    # PostToolUse contract in Antigravity requires {}
    printf '{}\n'
    exit 0
    ;;

  PostInvocation)
    # Drain any buffered notices and inject them as ephemeralMessage
    notices=()
    ws_list=("$proj")
    if [ -d "$proj/.solvers" ]; then
      for sw in "$proj"/.solvers/*; do
        [ -d "$sw" ] && ws_list+=("$sw")
      done
    fi

    for ws in "${ws_list[@]}"; do
      nf="$ws/.dev-rules/.agy-pending-notices"
      if [ -f "$nf" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
          [ -n "$line" ] && notices+=("$line")
        done < "$nf"
        rm -f "$nf"
      fi
    done

    if [ "${#notices[@]}" -gt 0 ]; then
      full_msg="$(printf '%s\n' "${notices[@]}")"
      jq -nc --arg msg "$full_msg" '{injectSteps: [{ephemeralMessage: $msg}]}'
    else
      printf '{}\n'
    fi
    exit 0
    ;;

  SessionStart)
    claude_input="$(jq -nc --arg cwd "$proj" '{cwd: $cwd}')"
    cmd="$(jq -r '.hooks.SessionStart[0].hooks[0].command // empty' "$CANONICAL_HOOKS" 2>/dev/null)"
    if [ -n "$cmd" ]; then
      hook_out="$(printf '%s' "$claude_input" | eval "$cmd" 2>/dev/null || true)"
      ctx="$(printf '%s' "$hook_out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
      if [ -n "$ctx" ]; then
        jq -nc --arg msg "$ctx" '{injectSteps: [{systemMessage: {systemMessage: $msg}}]}'
        exit 0
      fi
    fi
    printf '{}\n'
    exit 0
    ;;

  PreInvocation)
    claude_input="$(jq -nc --arg cwd "$proj" '{cwd: $cwd}')"
    cmd="$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command // empty' "$CANONICAL_HOOKS" 2>/dev/null)"
    if [ -n "$cmd" ]; then
      hook_out="$(printf '%s' "$claude_input" | eval "$cmd" 2>/dev/null || true)"
      ctx="$(printf '%s' "$hook_out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
      if [ -n "$ctx" ]; then
        jq -nc --arg msg "$ctx" '{injectSteps: [{ephemeralMessage: $msg}]}'
        exit 0
      fi
    fi
    printf '{}\n'
    exit 0
    ;;

  *)
    printf '{}\n'
    exit 0
    ;;
esac
