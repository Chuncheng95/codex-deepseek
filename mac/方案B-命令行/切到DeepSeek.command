#!/bin/bash
set -e
cd -- "$(dirname -- "$0")"
source ./_lib.sh

ensure_dirs

if [ ! -f "$CONFIG" ]; then
  echo "找不到 $CONFIG，请先安装并登录 Codex 桌面版。"
  pause_exit
  exit 1
fi

if [ "$(current_channel)" = "DeepSeek" ]; then
  echo "当前已经是 DeepSeek 通道，没有改动。"
  pause_exit
  exit 0
fi

model=$(top_value model)
if [ -n "$model" ] && [ "$model" != "deepseek-flash" ]; then
  printf '%s\n' "$model" > "$STATE_DIR/gpt-model"
fi

key=$(read_key_file)
bak=$(backup_config deepseek)

if [ -n "$key" ]; then
  upsert_provider "$key"
else
  echo "提示：没有读到 DeepSeek API Key，只切换通道，DeepSeek 可能无法通过认证。"
fi

apply_deepseek

echo "=========================================="
echo " 已切到 DeepSeek 通道"
echo " 备份：$bak"
echo " 请完全退出并重新打开 Codex 应用后生效"
echo "=========================================="
pause_exit
