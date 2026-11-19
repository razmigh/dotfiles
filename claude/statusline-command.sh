#!/usr/bin/env bash
# Claude Code status line: user@host dir (branch) model ctx:used/size usage
#
# usage depends on how Claude Code is billed:
#   subscription (Pro/Max): 5h / 7d rate limit percentages
#   behind a gateway with a spend limit: spent/limit in $ (or % until the amounts arrive)
#   API key / pay as you go: estimated session cost in $
#
# Reads the status JSON on stdin with jq, or python3 when jq is missing.
# Works with bash 3.2+ (macOS) and any POSIX awk/git; missing tools just hide their segment.

export LC_ALL=C
input=$(cat)

has() { command -v "$1" >/dev/null 2>&1; }

# One record of fields separated by \x1f so empty values survive `read`.
FIELDS_JQ='[
  (.workspace.current_dir // .cwd // ""),
  (.model.display_name // ""),
  (.context_window.current_usage
    | if type == "object"
      then (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
      else "" end),
  (.context_window.context_window_size // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.rate_limits.spend_limit.used_percentage // ""),
  (.rate_limits.spend_limit.used_usd // ""),
  (.rate_limits.spend_limit.limit_usd // ""),
  (.cost.total_cost_usd // "")
] | map(tostring) | join("\u001f")'

FIELDS_PY='
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
def get(*path):
    v = d
    for k in path:
        if not isinstance(v, dict):
            return None
        v = v.get(k)
    return v
def s(v):
    return "" if v is None or isinstance(v, (dict, list)) else str(v)
cu = get("context_window", "current_usage")
tokens = None
if isinstance(cu, dict):
    tokens = sum(int(cu.get(k) or 0) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
print("\x1f".join(s(v) for v in [
    get("workspace", "current_dir") or get("cwd"),
    get("model", "display_name"),
    tokens,
    get("context_window", "context_window_size"),
    get("rate_limits", "five_hour", "used_percentage"),
    get("rate_limits", "seven_day", "used_percentage"),
    get("rate_limits", "spend_limit", "used_percentage"),
    get("rate_limits", "spend_limit", "used_usd"),
    get("rate_limits", "spend_limit", "limit_usd"),
    get("cost", "total_cost_usd"),
]))
'

parse() {
  if has jq; then
    printf '%s' "$input" | jq -r "$FIELDS_JQ" 2>/dev/null
  elif has python3; then
    printf '%s' "$input" | python3 -c "$FIELDS_PY" 2>/dev/null
  elif has python; then
    printf '%s' "$input" | python -c "$FIELDS_PY" 2>/dev/null
  fi
}

IFS=$'\x1f' read -r cwd model ctx_used ctx_size rate_5h rate_7d spend_pct spend_usd spend_limit cost < <(parse)

[ -n "$cwd" ] || cwd=$PWD
user=${USER:-$(id -un 2>/dev/null)}
host=$(uname -n 2>/dev/null | cut -d. -f1)
short_cwd=${cwd/#"$HOME"/\~}

git_branch=""
if has git && [ -d "$cwd" ]; then
  # GIT_OPTIONAL_LOCKS=0: don't take index.lock while Claude may be running git itself
  git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null ||
    GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# 1234 -> 1k, 95000 -> 95k, 1200000 -> 1.2m
compact_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) { v = n / 1000000; fmt = (v == int(v)) ? "%dm" : "%.1fm" }
    else if (n >= 1000) { v = n / 1000; fmt = (v == int(v)) ? "%dk" : "%.0fk" }
    else { v = n; fmt = "%d" }
    printf fmt, v
  }'
}

# Percentage segment, green < 50 <= yellow < 80 <= red
pct() {
  local p color=32
  p=$(printf '%.0f' "$2" 2>/dev/null) || return 0
  [ "$p" -ge 50 ] && color=33
  [ "$p" -ge 80 ] && color=31
  printf ' \033[%sm%s:%s%%\033[0m' "$color" "$1" "$p"
}

usd() { printf '%.2f' "$1" 2>/dev/null; }

# ANSI colors (Claude Code dims them): user@host cyan, dir blue, branch yellow, model magenta, ctx green
printf '\033[36m%s@%s\033[0m \033[34m%s\033[0m' "$user" "$host" "$short_cwd"

[ -n "$git_branch" ] && printf ' \033[33m(%s)\033[0m' "$git_branch"
[ -n "$model" ] && printf ' \033[35m%s\033[0m' "$model"

if [ -n "$ctx_used" ] && [ -n "$ctx_size" ]; then
  printf ' \033[32mctx:%s/%s\033[0m' "$(compact_tokens "$ctx_used")" "$(compact_tokens "$ctx_size")"
fi

# rate_limits only exist for subscriptions/gateways; everyone else sees the session cost.
if [ -n "$rate_5h$rate_7d$spend_pct" ]; then
  [ -n "$rate_5h" ] && pct 5h "$rate_5h"
  [ -n "$rate_7d" ] && pct 7d "$rate_7d"
  if [ -n "$spend_usd" ] && [ -n "$spend_limit" ]; then
    printf ' \033[33m$%s/$%s\033[0m' "$(usd "$spend_usd")" "$(usd "$spend_limit")"
  elif [ -n "$spend_pct" ]; then
    pct spend "$spend_pct"
  fi
elif [ -n "$cost" ]; then
  printf ' \033[33m$%s\033[0m' "$(usd "$cost")"
fi

printf '\n'
