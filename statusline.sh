#!/bin/bash
# ============================================================================
# Claude Code Statusline — DeepSeek Edition
# Show model, context window, token usage, session cost & account balance.
#
# Supports: DeepSeek-V4-Pro, DeepSeek-V4-Flash (extensible)
# Pricing:  https://api-docs.deepseek.com/zh-cn/quick_start/pricing
# Balance:  https://api.deepseek.com/user/balance
#
# Required env vars:
#   DEEPSEEK_API_TOKEN   — DeepSeek API key (falls back to ANTHROPIC_AUTH_TOKEN)
# ============================================================================

set -euo pipefail

# ---- read JSON from Claude Code stdin ---------------------------------------
input=$(cat)

# ---- model info --------------------------------------------------------------
model=$(echo "$input" | jq -r '.model.display_name')
model_id=$(echo "$input" | jq -r '.model.id // ""')

# ---- context window ----------------------------------------------------------
used=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
[ "$used" = "null" ] && used=0
pct=$(printf "%.0f" "$used")

# 10-segment progress bar
filled=$((pct / 10))
[ $filled -gt 10 ] && filled=10
bar=""
for i in 0 1 2 3 4 5 6 7 8 9; do
  if [ $i -lt $filled ]; then bar="${bar}█"; else bar="${bar}░"; fi
done

# color: green (≤50%) / yellow (51-80%) / red (>80%)
if   [ $pct -gt 80 ]; then bar_color="31"
elif [ $pct -gt 50 ]; then bar_color="33"
else bar_color="32"
fi

# ---- context window snapshot (for progress bar reference) --------------------
total_in=$(echo "$input"  | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
[ "$total_in"  = "null" ] && total_in=0
[ "$total_out" = "null" ] && total_out=0

# ---- cumulative session cost (uncached tokens only, avoids double-counting) ---
cur_in=$(echo "$input"    | jq -r '.context_window.current_usage.input_tokens // 0')
cur_cache=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cur_out=$(echo "$input"   | jq -r '.context_window.current_usage.output_tokens // 0')
[ "$cur_in"    = "null" ] && cur_in=0
[ "$cur_cache" = "null" ] && cur_cache=0
[ "$cur_out"   = "null" ] && cur_out=0

cur_in_uncached=$((cur_in - cur_cache))
[ $cur_in_uncached -lt 0 ] && cur_in_uncached=$cur_in

sid=$(echo "$input" | jq -r '.session_id // "default"')
STATE="$HOME/.claude/.sl_state_${sid}"
cum_in=0; cum_out=0
if [ -f "$STATE" ]; then
  cum_in=$(head -1 "$STATE")
  cum_out=$(tail -1 "$STATE")
fi
cum_in=$((cum_in + cur_in_uncached))
cum_out=$((cum_out + cur_out))
echo "$cum_in"  > "$STATE"
echo "$cum_out" >> "$STATE"

# ---- pricing table (CNY per 1M tokens) --------------------------------------
# Update this section when DeepSeek pricing changes.
# Reference: https://api-docs.deepseek.com/zh-cn/quick_start/pricing
case "$model_id" in
  *deepseek-v4-pro*)
    in_pr=3; out_pr=6; pr_lbl='¥6/M (output)' ;;
  *deepseek-v4-flash*)
    in_pr=1; out_pr=2; pr_lbl='¥2/M (output)' ;;
  *)
    in_pr=0; out_pr=0; pr_lbl='' ;;
esac

# ---- formatters --------------------------------------------------------------
fmt_t() {
  # Format token count: 1M+ → X.XM, 1K+ → X.XK, else raw
  if [ "$1" -ge 1000000 ]; then
    awk "BEGIN { printf \"%.1fM\", $1 / 1000000 }"
  elif [ "$1" -ge 1000 ]; then
    awk "BEGIN { printf \"%.1fK\", $1 / 1000 }"
  else
    echo "$1"
  fi
}

# ---- cost calculation --------------------------------------------------------
sc=""
if [ "$in_pr" -gt 0 ] && [ "$cum_in$cum_out" != "00" ]; then
  sc=$(awk "BEGIN { printf \"%.4f\", ($cum_in * $in_pr + $cum_out * $out_pr) / 1000000 }")
fi

# ---- balance API (cached 5 min) ----------------------------------------------
CACHE="$HOME/.claude/.ds-bal"
BAL_JSON=""
if [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || stat -c %Y "$CACHE" 2>/dev/null || echo 999999) )) -lt 300 ]; then
  BAL_JSON=$(cat "$CACHE")
else
  TOKEN="${DEEPSEEK_API_TOKEN:-${ANTHROPIC_AUTH_TOKEN:-}}"
  BAL_JSON=$(curl -s --max-time 3 \
    "https://api.deepseek.com/user/balance" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null)
  if echo "$BAL_JSON" | jq -e '.balance_infos' >/dev/null 2>&1; then
    echo "$BAL_JSON" > "$CACHE"
  elif [ -f "$CACHE" ]; then
    BAL_JSON=$(cat "$CACHE")
  fi
fi

# ---- assemble output ---------------------------------------------------------
out=""

# 1. Model
out="${out}$(printf '\033[1;37m🤖 %s\033[0m' "$model")"

# 2. Context bar + percentage
out="${out}$(printf ' \033[%sm[%s]\033[0m \033[%sm%d%%\033[0m' \
  "$bar_color" "$bar" "$bar_color" "$pct")"

# 3. Token counts (total in context window)
in_f=$(fmt_t "$cum_in")
out_f=$(fmt_t "$cum_out")
out="${out}$(printf ' \033[2m|\033[0m \033[36m⬇ %s\033[0m \033[35m⬆ %s\033[0m' "$in_f" "$out_f")"

# 4. Session cost (cumulative, uncached tokens)
if [ -n "$sc" ] && [ "$sc" != "0.0000" ]; then
  sc_disp=$(awk "BEGIN { v=$sc; if(v<0.01) printf \"%.4f\", v; else if(v<1) printf \"%.3f\", v; else printf \"%.2f\", v }")
  out="${out}$(printf ' \033[2m|\033[0m \033[33m💰 ¥%s\033[0m' "$sc_disp")"
fi

# 5. Account balance + pricing
if [ -n "$BAL_JSON" ]; then
  BALANCE=$(echo "$BAL_JSON" | jq -r '.balance_infos[0].total_balance // ""' 2>/dev/null)
  if [ -n "$BALANCE" ] && [ "$BALANCE" != "null" ]; then
    out="${out}$(printf ' \033[2m|\033[0m \033[2m💳 ¥%s\033[0m' "$BALANCE")"
    [ -n "$pr_lbl" ] && out="${out}$(printf ' \033[2m[%s]\033[0m' "$pr_lbl")"
  fi
fi

printf '%s\n' "$out"
