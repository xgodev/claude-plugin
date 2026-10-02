#!/usr/bin/env bash
# Responsibility: report days whose token spend shows subagent fan-out, oversized contexts or a blown budget.
set -uo pipefail

# The other checks watch the causes; this one reads the bill itself, from the
# session transcripts. Every request re-sends its whole context, so input
# tokens (fresh + cache read + cache write) are what the spend is made of.
python3 <<'PY'
import glob, json, os, time, collections

home = os.environ["HYGIENE_HOME"]
days = int(os.environ.get("HYGIENE_USAGE_DAYS", "7"))
max_share = float(os.environ.get("HYGIENE_USAGE_SUBAGENT_PCT", "20"))
max_ctx = int(os.environ.get("HYGIENE_USAGE_CTX_TOKENS", "200000"))
max_day = int(os.environ.get("HYGIENE_USAGE_DAY_TOKENS", "1000000000"))

since = time.time() - days * 86400
cutoff = time.strftime("%Y-%m-%d", time.gmtime(since))
files = glob.glob(f"{home}/projects/*/*.jsonl") + glob.glob(f"{home}/projects/*/*/subagents/*.jsonl")

# day -> [total, subagent, requests]; project totals for naming the culprit.
day = collections.defaultdict(lambda: [0, 0, 0])
sub_by_project = collections.defaultdict(lambda: collections.Counter())
seen = set()
for path in files:
    try:
        if os.path.getmtime(path) < since:
            continue
        lines = open(path, errors="ignore")
    except OSError:
        continue
    project = os.path.relpath(path, f"{home}/projects").split(os.sep)[0]
    in_subagent_file = f"{os.sep}subagents{os.sep}" in path
    for line in lines:
        if '"usage"' not in line:
            continue
        try:
            d = json.loads(line)
        except ValueError:
            continue
        m = d.get("message")
        if not isinstance(m, dict) or not isinstance(m.get("usage"), dict):
            continue
        stamp = (d.get("timestamp") or "")[:10]
        if stamp < cutoff:
            continue
        # Streaming writes one message over several lines with the same usage.
        key = m.get("id") or d.get("requestId") or d.get("uuid")
        if key:
            if key in seen:
                continue
            seen.add(key)
        u = m["usage"]
        tokens = u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0) + u.get("cache_creation_input_tokens", 0)
        row = day[stamp]
        row[0] += tokens
        row[2] += 1
        if in_subagent_file or d.get("isSidechain"):
            row[1] += tokens
            sub_by_project[stamp][project] += tokens

def human(n):
    for unit, size in (("B", 1e9), ("M", 1e6), ("k", 1e3)):
        if n >= size:
            return f"{n / size:.1f}{unit}".replace(".0", "")
    return str(n)

for stamp in sorted(day):
    total, sub, requests = day[stamp]
    if not total:
        continue
    share = 100 * sub / total
    per_request = total // max(requests, 1)
    if share > max_share:
        top, top_tokens = sub_by_project[stamp].most_common(1)[0]
        print(f"  {stamp}: subagents were {share:.0f}% of {human(total)} tokens (limit {max_share:.0f}%)")
        print(f"      most in {top}: {human(top_tokens)}")
    if per_request > max_ctx:
        print(f"  {stamp}: {human(per_request)} tokens of context per request (limit {human(max_ctx)}) - sessions run too long before compacting")
    if max_day and total > max_day:
        print(f"  {stamp}: {human(total)} input tokens in the day (limit {human(max_day)})")
PY
