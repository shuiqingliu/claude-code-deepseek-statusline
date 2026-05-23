# Claude Code Statusline — DeepSeek Edition

A feature-rich status line for [Claude Code](https://code.claude.com/) when using DeepSeek models. Shows model info, context window usage, token counts, session cost, and account balance — all in one glance.

![screenshot](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue) ![license](https://img.shields.io/badge/license-MIT-green)

```
🤖 deepseek-v4-pro[1m]  [██████░░░░] 60%  |  ⬇ 73K ⬆ 186  |  💰 ¥0.85  |  💳 ¥49.36 [¥6/M (output)]
```

## Features

| Module | Icon | Description |
|--------|------|-------------|
| Model | `🤖` | Current model display name |
| Context | `[██████░░░░]` | 10-segment progress bar + percentage, color-coded (green/yellow/red) |
| Tokens | `⬇` / `⬆` | Total input/output tokens in the context window (auto-formatted K/M) |
| Cost | `💰` | Cumulative session cost in CNY, based on uncached token usage |
| Balance | `💳` | DeepSeek account balance (cached 5 min) + model output pricing |

## Prerequisites

- [Claude Code](https://code.claude.com/) v2.1.132+
- [jq](https://jqlang.github.io/jq/) (JSON processor)
- [curl](https://curl.se/)
- A DeepSeek API account

## Quick Install

```bash
# 1. Clone and copy the script
git clone https://github.com/your-org/claude-code-deepseek-statusline.git
cp claude-code-deepseek-statusline/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh

# 2. Set your DeepSeek API token
export DEEPSEEK_API_TOKEN="sk-your-deepseek-api-key"

# 3. Add to ~/.claude/settings.json:
# {
#   "statusLine": {
#     "type": "command",
#     "command": "~/.claude/statusline.sh"
#   }
# }
```

Or use the `/statusline` command in Claude Code and point it to the script.

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DEEPSEEK_API_TOKEN` | Yes | Your DeepSeek API key |
| `ANTHROPIC_AUTH_TOKEN` | No | Fallback if `DEEPSEEK_API_TOKEN` is not set |

### Pricing

Pricing is hardcoded based on [DeepSeek official pricing](https://api-docs.deepseek.com/zh-cn/quick_start/pricing) (CNY per 1M tokens):

| Model | Input | Output | Label |
|-------|-------|--------|-------|
| DeepSeek-V4-Pro | ¥3 | ¥6 | `¥6/M (output)` |
| DeepSeek-V4-Flash | ¥1 | ¥2 | `¥2/M (output)` |

> **Note:** V4-Pro pricing reflects the current 75%-off promotion (ends 2026-05-31). Update the `in_pr`/`out_pr` variables in `statusline.sh` when pricing changes.

### Cache

- **Balance cache**: 5 minutes (`~/.claude/.ds-bal`)
- **Token state**: per-session (`~/.claude/.sl_state_<session_id>`)

Clear caches:
```bash
rm -f ~/.claude/.ds-bal ~/.claude/.sl_state_*
```

## How It Works

1. Claude Code pipes session JSON to the script via stdin on each update
2. The script extracts model, context window, and token usage with `jq`
3. Cost is calculated from **uncached** tokens only — cache-hit tokens cost virtually nothing and are excluded
4. Balance is fetched from `https://api.deepseek.com/user/balance` and cached for 5 minutes
5. Cumulative tokens are tracked per session via state files, so cost grows across your entire conversation

## Format Reference

- Token counts: `≥1M` → `X.XM`, `≥1K` → `X.XK`, otherwise raw
- Cost precision: `< ¥0.01` → 4 decimals, `< ¥1` → 3 decimals, `≥ ¥1` → 2 decimals
- Context bar colors: green ≤ 50%, yellow 51-80%, red > 80%

## Use Cases

- **Cost monitoring**: Track session spend in real-time while coding with DeepSeek models
- **Context awareness**: The progress bar and percentage help you know when to `/compact`
- **Balance tracking**: Never get surprised by a zero balance mid-session
- **Multi-account**: Switch DeepSeek accounts via the `DEEPSEEK_API_TOKEN` env var

## Adding More Models

Edit the `case` block in `statusline.sh`:

```bash
case "$model_id" in
  *deepseek-v4-pro*)   in_pr=3;  out_pr=6;  pr_lbl='¥6/M (output)' ;;
  *deepseek-v4-flash*) in_pr=1;  out_pr=2;  pr_lbl='¥2/M (output)' ;;
  *your-model-here*)   in_pr=X;  out_pr=Y;  pr_lbl='¥Y/M (output)' ;;
esac
```

## License

MIT — see [LICENSE](LICENSE) file.

## See Also

- [Claude Code Statusline Docs](https://code.claude.com/docs/en/statusline)
- [DeepSeek API Pricing](https://api-docs.deepseek.com/zh-cn/quick_start/pricing)
- [DeepSeek Balance API](https://api.deepseek.com/user/balance)
