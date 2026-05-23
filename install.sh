#!/bin/bash
# ============================================================================
# Quick install script for Claude Code DeepSeek Statusline
# ============================================================================
set -euo pipefail

RED='\033[31m'; GREEN='\033[32m'; CYAN='\033[36m'; RESET='\033[0m'
echo -e "${CYAN}Claude Code Statusline — DeepSeek Edition${RESET}"
echo ""

# ---- check dependencies -----------------------------------------------------
for cmd in jq curl; do
  if ! command -v $cmd &>/dev/null; then
    echo -e "${RED}Missing dependency: $cmd${RESET}"
    echo "Install: brew install $cmd"
    exit 1
  fi
done

# ---- copy script ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$HOME/.claude/statusline.sh"
echo -e "${GREEN}✓${RESET} Script installed to ~/.claude/statusline.sh"

# ---- API token ---------------------------------------------------------------
if [ -z "${DEEPSEEK_API_TOKEN:-}" ] && [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  echo ""
  echo -e "${CYAN}Set your DeepSeek API token (one of):${RESET}"
  echo "  export DEEPSEEK_API_TOKEN=\"sk-your-token\""
  echo "  # or if you already use ANTHROPIC_AUTH_TOKEN for DeepSeek:"
  echo "  export ANTHROPIC_AUTH_TOKEN=\"sk-your-token\""
else
  echo -e "${GREEN}✓${RESET} API token found in environment"
fi

# ---- configure settings.json ------------------------------------------------
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  # Check if statusLine already exists
  if python3 -c "import json; d=json.load(open('$SETTINGS')); exit(0 if 'statusLine' in d else 1)" 2>/dev/null; then
    echo -e "${CYAN}!${RESET} statusLine already configured in settings.json, skipping"
  else
    python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
d['statusLine'] = {'type': 'command', 'command': '$HOME/.claude/statusline.sh'}
with open('$SETTINGS', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
"
    echo -e "${GREEN}✓${RESET} Added statusLine to ~/.claude/settings.json"
  fi
else
  echo '{"statusLine":{"type":"command","command":"'$HOME'/.claude/statusline.sh"}}' > "$SETTINGS"
  echo -e "${GREEN}✓${RESET} Created ~/.claude/settings.json with statusLine"
fi

echo ""
echo -e "${GREEN}Done!${RESET} The status line will appear after your next interaction with Claude Code."
echo ""
echo "To customize:"
echo "  - Edit pricing:   vim ~/.claude/statusline.sh"
echo "  - Clear caches:   rm -f ~/.claude/.ds-bal ~/.claude/.sl_state_*"
echo "  - Uninstall:      rm ~/.claude/statusline.sh  # and remove statusLine from settings.json"
