# Claude Code 状态栏 — DeepSeek 专版

一个功能丰富的 [Claude Code](https://code.claude.com/) 状态栏，专为 DeepSeek 模型用户打造。一目了然地展示模型信息、上下文窗口、Token 用量、会话花费和账户余额。

![screenshot](screenshot.png)

> [English](README.md) | [中文文档](README_CN.md)

## 功能模块

| 模块 | 图标 | 说明 |
|------|------|------|
| 模型 | `🤖` | 当前模型名称 |
| 上下文 | `[██████░░░░]` | 10 格进度条 + 百分比，绿/黄/红三色预警 |
| Token | `⬇` / `⬆` | 会话累计输入/输出 Token（非缓存，自动格式化为 K/M） |
| 花费 | `💰` | 当前会话累计费用（人民币），仅计算非缓存 Token |
| 余额 | `💳` | DeepSeek 账户余额（缓存 5 分钟）+ 模型输出单价 |

## 环境要求

- [Claude Code](https://code.claude.com/) v2.1.132+
- [jq](https://jqlang.github.io/jq/)（JSON 处理工具）
- [curl](https://curl.se/)
- Claude Code 已按 [DeepSeek 官方指南](https://github.com/deepseek-ai/awesome-deepseek-agent/blob/main/docs/claude_code.md#option-1-configure-via-configuration-file) 配置好 DeepSeek 模型。余额检查会自动复用你已有的 `ANTHROPIC_AUTH_TOKEN`。

## 快速安装

```bash
# 1. 克隆仓库并复制脚本
git clone https://github.com/shuiqingliu/claude-code-deepseek-statusline.git
cp claude-code-deepseek-statusline/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh

# 2. 在 ~/.claude/settings.json 中添加（已配置 DeepSeek 则无需额外 token）：
# {
#   "statusLine": {
#     "type": "command",
#     "command": "~/.claude/statusline.sh"
#   }
# }
```

或者在 Claude Code 中使用 `/statusline` 命令指向该脚本。

## 配置说明

### API Token

如果你已按 [DeepSeek 官方指南](https://github.com/deepseek-ai/awesome-deepseek-agent/blob/main/docs/claude_code.md#option-1-configure-via-configuration-file) 配置了 Claude Code，**无需额外设置 token**。脚本会自动复用 `~/.claude/settings.json` 中已有的 `ANTHROPIC_AUTH_TOKEN`。

如需为余额 API 使用独立 token：

| 变量 | 必填 | 说明 |
|------|------|------|
| `ANTHROPIC_AUTH_TOKEN` | 自动 | DeepSeek API 密钥（按官方指南配置后自动可用） |
| `DEEPSEEK_API_TOKEN` | 否 | 仅需为余额检查使用不同密钥时设置 |

### 价格表

根据 [DeepSeek 官方定价](https://api-docs.deepseek.com/zh-cn/quick_start/pricing)（每百万 Token，人民币）：

| 模型 | 输入价格 | 输出价格 | 标签 |
|------|----------|----------|------|
| DeepSeek-V4-Pro | ¥3 | ¥6 | `¥6/M (output)` |
| DeepSeek-V4-Flash | ¥1 | ¥2 | `¥2/M (output)` |

> **注意：** V4-Pro 价格为当前 2.5 折优惠价（截止 2026-05-31）。价格变动时请更新 `statusline.sh` 中的 `in_pr`/`out_pr` 变量。

### 缓存文件

- **余额缓存**：5 分钟（`~/.claude/.ds-bal`）
- **Token 状态**：按会话存储（`~/.claude/.sl_state_<session_id>`）

清理缓存：
```bash
rm -f ~/.claude/.ds-bal ~/.claude/.sl_state_*
```

## 工作原理

1. Claude Code 在每次更新时将会话 JSON 通过 stdin 传给脚本
2. 脚本使用 `jq` 解析模型、上下文窗口和 Token 数据
3. Token 展示和费用仅按**非缓存 Token** 累计 — 缓存命中的 Token 几乎免费，不计入费用
4. 余额通过 `https://api.deepseek.com/user/balance` 获取，缓存 5 分钟
5. 累计 Token 按会话存储，费用随整个对话过程持续增长

## 格式化规则

- Token 数量：`≥1M` → `X.XM`，`≥1K` → `X.XK`，否则显示原始值
- 费用精度：`< ¥0.01` → 4 位小数，`< ¥1` → 3 位小数，`≥ ¥1` → 2 位小数
- 进度条颜色：绿色 ≤ 50%，黄色 51-80%，红色 > 80%

## 使用场景

- **费用监控**：使用 DeepSeek 模型编程时实时追踪会话费用
- **上下文感知**：进度条和百分比帮你判断何时需要 `/compact`
- **余额追踪**：不会在会话中途突然发现余额不足
- **多账号管理**：如需为余额检查使用不同账号，可设置 `DEEPSEEK_API_TOKEN` 环境变量

## 添加更多模型

编辑 `statusline.sh` 中的 `case` 分支：

```bash
case "$model_id" in
  *deepseek-v4-pro*)   in_pr=3;  out_pr=6;  pr_lbl='¥6/M (output)' ;;
  *deepseek-v4-flash*) in_pr=1;  out_pr=2;  pr_lbl='¥2/M (output)' ;;
  *你的模型名称*)       in_pr=X;  out_pr=Y;  pr_lbl='¥Y/M (output)' ;;
esac
```

## 开源协议

MIT — 详见 [LICENSE](LICENSE) 文件。

## 相关链接

- [Claude Code 状态栏文档](https://code.claude.com/docs/en/statusline)
- [DeepSeek Claude Code 官方配置指南](https://github.com/deepseek-ai/awesome-deepseek-agent/blob/main/docs/claude_code.md)
- [DeepSeek API 定价](https://api-docs.deepseek.com/zh-cn/quick_start/pricing)
- [DeepSeek 余额 API](https://api.deepseek.com/user/balance)
